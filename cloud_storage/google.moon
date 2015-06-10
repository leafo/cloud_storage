
url = require "socket.url"
date = require "date"
ltn12 = require "ltn12"
json = require "cjson"
mime = require "mime"

mimetypes = require "mimetypes"

h = require "cloud_storage.http"

import insert, concat from table

url_encode_key = (key) ->
  (key\gsub [==[[%[%]#!%^%*%(%)"'%%]]==], (c) ->
    "%#{"%x"\format(c\byte!)\upper!}")

extend = (t, ...) ->
  for other in *{...}
    if other != nil
      t[k] = v for k,v in pairs other
  t

class LOMFormatter
  find_node = (node, tag) ->
    for child in *node
      if child.tag == tag
        return child

  filter_nodes = (node, tag) ->
    return for child in *node
      continue unless child.tag == tag
      child

  node_value = (node, tag) ->
    child = find_node node, tag
    child and child[1]

  new: =>
    @lom = require "lxp.lom"

  format: (res, code, headers) =>
    return code, headers if res == ""
    return res if headers["x-goog-generation"]

    res = @lom.parse res
    return nil, "Failed to parse result #{code}" if not res

    if @[res.tag]
      @[res.tag] @, res
    else
      res, code

  "ListAllMyBucketsResult": (res) =>
    buckets_node = find_node res, "Buckets"
    return for bucket in *buckets_node
      {
        name: node_value bucket, "Name"
        creation_date: node_value bucket, "CreationDate"
      }

  "ListBucketResult": (res) =>
    return for node in *filter_nodes res, "Contents"
      {
        key: node_value node, "Key"
        size: tonumber node_value node, "Size"
        last_modified: node_value node, "LastModified"
      }

  "Error": (res) =>
    {
      error: true
      message: node_value res, "Message"
      code: node_value res, "Code"
      details: node_value res, "Details"
    }

class Bucket
  forward_methods = {
    "get_bucket": "list"
    "get_file"
    "delete_file"
    "head_file"
    "put_file"
    "put_file_string"
    "file_url"
  }

  new: (@bucket_name, @storage) =>

  for k,v in pairs forward_methods
    name, self_name = if type(k) == "number"
      v,v
    else
      k,v

    @__base[self_name] = (...) =>
      @storage[name] @storage, @bucket_name, ...

class CloudStorage
  url_base: "commondatastorage.googleapis.com"

  new: (@oauth, @project_id) =>
    @formatter = LOMFormatter!

  _headers: =>
    {
      "x-goog-api-version": 2
      "x-goog-project-id": @project_id
      "Authorization": "OAuth #{@oauth\get_access_token!}"
      "Date": date!\fmt "${http}"
    }
  
  _request: (method="GET", path, data, headers) =>
    http = h.get!

    out = {}
    r = {
      url: url.build {
        scheme: "https"
        host: "storage.googleapis.com"
        path: path
      }
      source: data and ltn12.source.string data
      method: method
      headers: extend @_headers!, headers
      sink: ltn12.sink.table out
    }
    _, code, res_headers = http.request r
    @formatter\format table.concat(out), code, res_headers

  bucket: (bucket) => Bucket bucket, @

  file_url: (bucket, key) =>
    @bucket_url(bucket) .. "/#{key}"

  bucket_url: (bucket, opts={}) =>
    scheme = opts.scheme or "http"
    if opts.subdomain
      "#{scheme}://#{bucket}.#{@url_base}"
    else
      "#{scheme}://#{@url_base}/#{bucket}"

  for m in *{"GET", "POST", "PUT", "DELETE", "HEAD"}
    @__base["_#{m\lower!}"] = (...) => @_request m, ...

  get_service: => @_get "/"
  get_bucket: (bucket) => @_get "/#{bucket}"
  get_file: (bucket, key) => @_get "/#{bucket}/#{key}"
  delete_file: (bucket, key) => @_delete "/#{bucket}/#{key}"
  head_file: (bucket, key) => @_head "/#{bucket}/#{key}"

  -- sets predefined acl
  put_file_acl: (bucket, key, acl) =>
    error "broken"
    @_put "/#{bucket}/#{key}?acl", "", {
      "Content-length": 0
      "x-goog-acl": acl
    }

  put_file_string: (bucket, data, options={}) =>
    @_put "/#{bucket}/#{options.key}", data, extend {
      "Content-length": #data
      "Content-type": options.mimetype
      "x-goog-acl": options.acl or "public-read"
    }, options.headers

  put_file: (bucket, fname, options={}) =>
    data = if f = io.open fname
      with f\read "*a"
        f\close!
    else
      error "Failed to read file: #{fname}"

    options.mimetype or= mimetypes.guess fname
    options.key or= fname
    @put_file_string bucket, data, options

  encode_and_sign_policy: (expiration, conditions) =>
    if type(expiration) == "number"
      expiration = os.date "!%Y-%m-%dT%H:%M:%SZ", expiration

    doc = mime.b64 json.encode { :expiration, :conditions }
    doc, @oauth\sign_string doc

  -- expiration: unix timestamp in UTC
  signed_url: (bucket, key, expiration) =>
    key = url_encode_key key

    path = "/#{bucket}/#{key}"
    expiration = tostring expiration

    str = concat {
      "GET" -- verb
      "" -- md5
      "" -- content-type
      expiration
      "" -- trailing newline
    }, "\n"

    str ..= path

    signature = @oauth\sign_string str

    escape = (str) ->
      (str\gsub "[/+]", {
        "+": "%2B"
        "/": "%2F"
      })

    concat {
      "http://#{@url_base}"
      path
      "?GoogleAccessId=", @oauth.client_email
      "&Expires=", expiration
      "&Signature=", escape signature
    }

  upload_url: (bucket, key, opts={}) =>
    {
      :content_disposition, :filename, :acl, :success_action_redirect,
      :expires, :size_limit
    } = opts

    expires or= os.time! + 60^2
    acl or= "project-private"

    if filename
      content_disposition or= "attachment"
      filename_quoted = filename\gsub '"', "\\%1"
      content_disposition ..= "; filename=\"#{filename_quoted}\""

    policy = {}
    insert policy, { :acl }
    insert policy, { :bucket }
    insert policy, {"eq", "$key", key}

    if content_disposition
      insert policy, {"eq", "$Content-Disposition", content_disposition}

    if size_limit
      insert policy, {"content-length-range", 0, size_limit}

    if success_action_redirect
      insert policy, { :success_action_redirect }

    policy, signature = @encode_and_sign_policy expires, policy

    action = @bucket_url bucket, subdomain: true

    unless opts.https == false
      action = action\gsub("http:", "https:") or action

    params = {
      :acl, :policy, :signature, :key
      :success_action_redirect

      "Content-Disposition": content_disposition
      GoogleAccessId: @oauth.client_email
    }

    action, params


{ :CloudStorage, :Bucket, :url_encode_key }
