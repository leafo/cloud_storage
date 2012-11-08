
https = require "ssl.https"
url = require "socket.url"
date = require "date"
ltn12 = require "ltn12"

mimetypes = require "mimetypes"

import insert, concat from table

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

  each_node = (node, tag) ->
    coroutine.wrap ->
      for child in *node
        if child.tag == tag
          coroutine.yield child

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
    return for node in each_node res, "Contents"
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
    _, code, res_headers = https.request r
    @formatter\format table.concat(out), code, res_headers

  bucket: (bucket) => Bucket bucket, @

  file_url: (bucket, key) =>
    "http://commondatastorage.googleapis.com/#{bucket}/#{key}"

  for m in *{"GET", "POST", "PUT", "DELETE", "HEAD"}
    @__base["_#{m\lower!}"] = (...) => @_request m, ...

  get_service: => @_get "/"
  get_bucket: (bucket) => @_get "/#{bucket}"
  get_file: (bucket, key) => @_get "/#{bucket}/#{key}"
  delete_file: (bucket, key) => @_delete "/#{bucket}/#{key}"
  head_file: (bucket, key) => select 2, @_head "/#{bucket}/#{key}"

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

{ :CloudStorage, :Bucket }

