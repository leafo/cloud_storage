
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

xml_escape = do
  punct = "[%^$()%.%[%]*+%-?]"
  escape_patt = (str) -> (str\gsub punct, (p) -> "%"..p)

  xml_escape_entities = {
    ['&']: '&amp;'
    ['<']: '&lt;'
    ['>']: '&gt;'
    ['"']: '&quot;'
    ["'"]: '&#039;'
  }

  xml_unescape_entities = {}
  for key,value in pairs xml_escape_entities
    xml_unescape_entities[value] = key

  xml_escape_pattern = "[" .. concat([escape_patt char for char in pairs xml_escape_entities]) .. "]"

  (text) -> (text\gsub xml_escape_pattern, xml_escape_entities)

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
  api_base: "storage.googleapis.com"

  @from_json_key_file: (file) =>
    file_contents = assert assert(io.open(file))\read "*a"
    json = require("cjson")
    obj = assert json.decode file_contents
    import OAuth from require "cloud_storage.oauth"

    oauth = OAuth obj.client_email
    oauth\_load_private_key obj.private_key

    CloudStorage oauth, obj.client_id

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
      url: "https://#{@api_base}#{path}"
      source: data and ltn12.source.string data
      method: method
      headers: extend @_headers!, headers
      sink: ltn12.sink.table out
    }

    _, code, res_headers = http.request r
    res, code = @formatter\format table.concat(out), code, res_headers

    if type(res) == "table" and res.error
      nil, "#{res.message} #{res.details}", res
    else
      res, code

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
  get_file: (bucket, key) => @_get "/#{bucket}/#{url.escape key}"
  delete_file: (bucket, key) => @_delete "/#{bucket}/#{url.escape key}"
  head_file: (bucket, key) => @_head "/#{bucket}/#{url.escape key}"

  -- sets predefined acl
  put_file_acl: (bucket, key, acl) =>
    @_put "/#{bucket}/#{url.escape key}?acl", "", {
      "Content-length": 0
      "x-goog-acl": acl
    }

  put_file_string: (bucket, key, data, options={}) =>
    assert not options.key, "key is not an option, but an argument"
    if type(data) == "table"
      error "put_file_string interface has changed: key is now the second argument"

    assert key, "missing key"
    assert type(data) == "string", "expected string for data"

    @_put "/#{bucket}/#{key}", data, extend {
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
    key = options.key or fname
    @put_file_string bucket, key, data, options

  copy_file: (source_bucket, source_key, dest_bucket, dest_key, options={}) =>
    @_put "/#{dest_bucket}/#{url.escape dest_key}", "", extend {
      "Content-length": "0"
      "x-goog-copy-source": "/#{source_bucket}/#{source_key}"
      "x-goog-acl": options.acl or "public-read"
      "x-goog-metadata-directive": options.metadata_directive
    }, options.headers

  compose: (bucket, key, source_keys, options={}) =>
    assert type(source_keys) == "table" and next(source_keys), "invalid source keys"

    payload_buffer = {"<ComposeRequest>"}
    for key_obj in *source_keys
      local name, generation, if_generation_match

      if type(key_obj) == "table"
        {:name, :generation, :if_generation_match}
      else
        name = key_obj

      assert name, "missing source key name for compose"
      table.insert payload_buffer, "<Component>"
      table.insert payload_buffer, "<Name>#{xml_escape name}</Name>"

      if generation
        table.insert payload_buffer, "<Generation>#{xml_escape generation}</Generation>"

      if if_generation_match
        table.insert payload_buffer, "<IfGenerationMatch>#{xml_escape if_generation_match}</IfGenerationMatch>"

      table.insert payload_buffer, "</Component>"

    table.insert payload_buffer, "</ComposeRequest>"

    payload = table.concat payload_buffer

    @_put "/#{bucket}/#{url.escape key}?compose", payload, extend {
      "Content-length": #payload
      "x-goog-acl": options.acl or "public-read"
      "Content-type": options.mimetype
    }, options.headers

  start_resumable_upload: (bucket, key, options={}) =>
    assert bucket, "missing bucket"
    assert key, "missing key"

    if type(key) == "table"
      options = key
      key = assert options.key, "missing key"

    @_post "/#{bucket}/#{url.escape key}", "", extend {
      "Content-type": options.mimetype
      "Content-length": 0
      "x-goog-acl": options.acl or "public-read"
      "x-goog-resumable": "start"
    }, options.headers

  canonicalize_headers: (headers) =>
    header_pairs = [{k\lower!,v} for k, v in pairs headers]
    -- only count custom headers (x-goog), omit secret encryption headers
    header_pairs = [e for e in *header_pairs when (e[1]\match("x%-goog.*") and not e[1]\match("x%-goog%-encryption%-key.*"))]

    table.sort header_pairs, (a, b) ->
      a[1] < b[1]
    -- replace folding whitespace with spaces
    values = [e[1] .. ":" .. e[2]\gsub("\r?\n", " ") for e in *header_pairs]
    return concat values, "\n"

  encode_and_sign_policy: (expiration, conditions) =>
    if type(expiration) == "number"
      expiration = os.date "!%Y-%m-%dT%H:%M:%SZ", expiration

    doc = mime.b64 json.encode { :expiration, :conditions }
    doc, @oauth\sign_string doc

  -- expiration: unix timestamp in UTC
  signed_url: (bucket, key, expiration, opts={}) =>
    key = url_encode_key key

    path = "/#{bucket}/#{key}"
    expiration = tostring expiration

    verb = opts.verb or "GET"

    elements = {
      verb
      "" -- md5
      "" -- content-type
      expiration
    }

    -- 'As Needed', not required
    if opts.headers and next opts.headers
      table.insert elements, @canonicalize_headers(opts.headers)

    table.insert elements, "" -- trailing newline

    str = concat elements, "\n"
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
