local url = require("socket.url")
local date = require("date")
local ltn12 = require("ltn12")
local json = require("cjson")
local mime = require("mime")
local mimetypes = require("mimetypes")
local h = require("cloud_storage.http")
local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local url_encode_key
url_encode_key = function(key)
  return (key:gsub([==[[%[%]#!%^%*%(%)"'%%]]==], function(c)
    return "%" .. tostring(("%x"):format(c:byte()):upper())
  end))
end
local extend
extend = function(t, ...)
  local _list_0 = {
    ...
  }
  for _index_0 = 1, #_list_0 do
    local other = _list_0[_index_0]
    if other ~= nil then
      for k, v in pairs(other) do
        t[k] = v
      end
    end
  end
  return t
end
local LOMFormatter
do
  local _class_0
  local find_node, filter_nodes, node_value
  local _base_0 = {
    format = function(self, res, code, headers)
      if res == "" then
        return code, headers
      end
      if headers["x-goog-generation"] then
        return res
      end
      res = self.lom.parse(res)
      if not res then
        return nil, "Failed to parse result " .. tostring(code)
      end
      if self[res.tag] then
        return self[res.tag](self, res)
      else
        return res, code
      end
    end,
    ["ListAllMyBucketsResult"] = function(self, res)
      local buckets_node = find_node(res, "Buckets")
      return (function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #buckets_node do
          local bucket = buckets_node[_index_0]
          _accum_0[_len_0] = {
            name = node_value(bucket, "Name"),
            creation_date = node_value(bucket, "CreationDate")
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()
    end,
    ["ListBucketResult"] = function(self, res)
      return (function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = filter_nodes(res, "Contents")
        for _index_0 = 1, #_list_0 do
          local node = _list_0[_index_0]
          _accum_0[_len_0] = {
            key = node_value(node, "Key"),
            size = tonumber(node_value(node, "Size")),
            last_modified = node_value(node, "LastModified")
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()
    end,
    ["Error"] = function(self, res)
      return {
        error = true,
        message = node_value(res, "Message"),
        code = node_value(res, "Code"),
        details = node_value(res, "Details")
      }
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      self.lom = require("lxp.lom")
    end,
    __base = _base_0,
    __name = "LOMFormatter"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  find_node = function(node, tag)
    for _index_0 = 1, #node do
      local child = node[_index_0]
      if child.tag == tag then
        return child
      end
    end
  end
  filter_nodes = function(node, tag)
    return (function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #node do
        local _continue_0 = false
        repeat
          local child = node[_index_0]
          if not (child.tag == tag) then
            _continue_0 = true
            break
          end
          local _value_0 = child
          _accum_0[_len_0] = _value_0
          _len_0 = _len_0 + 1
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return _accum_0
    end)()
  end
  node_value = function(node, tag)
    local child = find_node(node, tag)
    return child and child[1]
  end
  LOMFormatter = _class_0
end
local Bucket
do
  local _class_0
  local forward_methods
  local _base_0 = { }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, bucket_name, storage)
      self.bucket_name, self.storage = bucket_name, storage
    end,
    __base = _base_0,
    __name = "Bucket"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  forward_methods = {
    ["get_bucket"] = "list",
    "get_file",
    "delete_file",
    "head_file",
    "put_file",
    "put_file_string",
    "file_url"
  }
  for k, v in pairs(forward_methods) do
    local name, self_name
    if type(k) == "number" then
      name, self_name = v, v
    else
      name, self_name = k, v
    end
    self.__base[self_name] = function(self, ...)
      return self.storage[name](self.storage, self.bucket_name, ...)
    end
  end
  Bucket = _class_0
end
local CloudStorage
do
  local _class_0
  local _base_0 = {
    url_base = "commondatastorage.googleapis.com",
    _headers = function(self)
      return {
        ["x-goog-api-version"] = 2,
        ["x-goog-project-id"] = self.project_id,
        ["Authorization"] = "OAuth " .. tostring(self.oauth:get_access_token()),
        ["Date"] = date():fmt("${http}")
      }
    end,
    _request = function(self, method, path, data, headers)
      if method == nil then
        method = "GET"
      end
      local http = h.get()
      local out = { }
      local r = {
        url = url.build({
          scheme = "https",
          host = "storage.googleapis.com",
          path = path
        }),
        source = data and ltn12.source.string(data),
        method = method,
        headers = extend(self:_headers(), headers),
        sink = ltn12.sink.table(out)
      }
      local _, code, res_headers = http.request(r)
      return self.formatter:format(table.concat(out), code, res_headers)
    end,
    bucket = function(self, bucket)
      return Bucket(bucket, self)
    end,
    file_url = function(self, bucket, key)
      return self:bucket_url(bucket) .. "/" .. tostring(key)
    end,
    bucket_url = function(self, bucket, opts)
      if opts == nil then
        opts = { }
      end
      local scheme = opts.scheme or "http"
      if opts.subdomain then
        return tostring(scheme) .. "://" .. tostring(bucket) .. "." .. tostring(self.url_base)
      else
        return tostring(scheme) .. "://" .. tostring(self.url_base) .. "/" .. tostring(bucket)
      end
    end,
    get_service = function(self)
      return self:_get("/")
    end,
    get_bucket = function(self, bucket)
      return self:_get("/" .. tostring(bucket))
    end,
    get_file = function(self, bucket, key)
      return self:_get("/" .. tostring(bucket) .. "/" .. tostring(key))
    end,
    delete_file = function(self, bucket, key)
      return self:_delete("/" .. tostring(bucket) .. "/" .. tostring(key))
    end,
    head_file = function(self, bucket, key)
      return self:_head("/" .. tostring(bucket) .. "/" .. tostring(key))
    end,
    put_file_acl = function(self, bucket, key, acl)
      error("broken")
      return self:_put("/" .. tostring(bucket) .. "/" .. tostring(key) .. "?acl", "", {
        ["Content-length"] = 0,
        ["x-goog-acl"] = acl
      })
    end,
    put_file_string = function(self, bucket, data, options)
      if options == nil then
        options = { }
      end
      return self:_put("/" .. tostring(bucket) .. "/" .. tostring(options.key), data, extend({
        ["Content-length"] = #data,
        ["Content-type"] = options.mimetype,
        ["x-goog-acl"] = options.acl or "public-read"
      }, options.headers))
    end,
    put_file = function(self, bucket, fname, options)
      if options == nil then
        options = { }
      end
      local data
      do
        local f = io.open(fname)
        if f then
          do
            local _with_0 = f:read("*a")
            f:close()
            data = _with_0
          end
        else
          data = error("Failed to read file: " .. tostring(fname))
        end
      end
      options.mimetype = options.mimetype or mimetypes.guess(fname)
      options.key = options.key or fname
      return self:put_file_string(bucket, data, options)
    end,
    start_resumable_upload = function(self, bucket, options)
      if options == nil then
        options = { }
      end
      return self:_post("/" .. tostring(bucket) .. "/" .. tostring(options.key), "", extend({
        ["Content-type"] = options.mimetype,
        ["Content-length"] = 0,
        ["x-goog-acl"] = options.acl or "public-read",
        ["x-goog-resumable"] = "start"
      }, options.headers))
    end,
    encode_and_sign_policy = function(self, expiration, conditions)
      if type(expiration) == "number" then
        expiration = os.date("!%Y-%m-%dT%H:%M:%SZ", expiration)
      end
      local doc = mime.b64(json.encode({
        expiration = expiration,
        conditions = conditions
      }))
      return doc, self.oauth:sign_string(doc)
    end,
    signed_url = function(self, bucket, key, expiration)
      key = url_encode_key(key)
      local path = "/" .. tostring(bucket) .. "/" .. tostring(key)
      expiration = tostring(expiration)
      local str = concat({
        "GET",
        "",
        "",
        expiration,
        ""
      }, "\n")
      str = str .. path
      local signature = self.oauth:sign_string(str)
      local escape
      escape = function(str)
        return (str:gsub("[/+]", {
          ["+"] = "%2B",
          ["/"] = "%2F"
        }))
      end
      return concat({
        "http://" .. tostring(self.url_base),
        path,
        "?GoogleAccessId=",
        self.oauth.client_email,
        "&Expires=",
        expiration,
        "&Signature=",
        escape(signature)
      })
    end,
    upload_url = function(self, bucket, key, opts)
      if opts == nil then
        opts = { }
      end
      local content_disposition, filename, acl, success_action_redirect, expires, size_limit
      content_disposition, filename, acl, success_action_redirect, expires, size_limit = opts.content_disposition, opts.filename, opts.acl, opts.success_action_redirect, opts.expires, opts.size_limit
      expires = expires or (os.time() + 60 ^ 2)
      acl = acl or "project-private"
      if filename then
        content_disposition = content_disposition or "attachment"
        local filename_quoted = filename:gsub('"', "\\%1")
        content_disposition = content_disposition .. "; filename=\"" .. tostring(filename_quoted) .. "\""
      end
      local policy = { }
      insert(policy, {
        acl = acl
      })
      insert(policy, {
        bucket = bucket
      })
      insert(policy, {
        "eq",
        "$key",
        key
      })
      if content_disposition then
        insert(policy, {
          "eq",
          "$Content-Disposition",
          content_disposition
        })
      end
      if size_limit then
        insert(policy, {
          "content-length-range",
          0,
          size_limit
        })
      end
      if success_action_redirect then
        insert(policy, {
          success_action_redirect = success_action_redirect
        })
      end
      local signature
      policy, signature = self:encode_and_sign_policy(expires, policy)
      local action = self:bucket_url(bucket, {
        subdomain = true
      })
      if not (opts.https == false) then
        action = action:gsub("http:", "https:") or action
      end
      local params = {
        acl = acl,
        policy = policy,
        signature = signature,
        key = key,
        success_action_redirect = success_action_redirect,
        ["Content-Disposition"] = content_disposition,
        GoogleAccessId = self.oauth.client_email
      }
      return action, params
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, oauth, project_id)
      self.oauth, self.project_id = oauth, project_id
      self.formatter = LOMFormatter()
    end,
    __base = _base_0,
    __name = "CloudStorage"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  local _list_0 = {
    "GET",
    "POST",
    "PUT",
    "DELETE",
    "HEAD"
  }
  for _index_0 = 1, #_list_0 do
    local m = _list_0[_index_0]
    self.__base["_" .. tostring(m:lower())] = function(self, ...)
      return self:_request(m, ...)
    end
  end
  CloudStorage = _class_0
end
return {
  CloudStorage = CloudStorage,
  Bucket = Bucket,
  url_encode_key = url_encode_key
}
