
https = require "ssl.https"
url = require "socket.url"
date = require "date"
ltn12 = require "ltn12"

class LOMFormatter
  find_node = (node, tag) ->
    for sub_node in *node
      if sub_node.tag == tag
        return sub_node

  new: =>
    @lom = require "lxp.lom"

  format: (res) =>
    res = @lom.parse res
    if @[res.tag]
      @[res.tag] @, res
    else
      res

  "ListAllMyBucketsResult": (res) =>
    buckets_node = find_node res, "Buckets"
    return for bucket in *buckets_node
      {
        name: find_node(bucket, "Name")[1]
        creation_date: find_node(bucket, "CreationDate")[1]
      }

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
  
  _request: (method="GET", path) =>
    out = {}
    https.request {
      url: url.build {
        scheme: "https"
        host: "storage.googleapis.com"
        path: path
      }
      method: method
      headers: @_headers!
      sink: ltn12.sink.table out
    }
    @formatter\format table.concat out

  _get: (...) => @_request "GET", ...
  _post: (...) => @_request "POST", ...

  get_service: => @_get "/"

{ :CloudStorage }

