local Bucket
Bucket = require("cloud_storage.google").Bucket
local lfs = require("lfs")
local VALID_NAME_CHUNK = "^[%w%._%-]+$"
local BUCKET_PATTERN = "^[a-z0-9][a-z0-9._-]*[a-z0-9]$"
local BUCKET_MIN_LEN = 3
local BUCKET_MAX_LEN = 63
local validate_bucket
validate_bucket = function(bucket)
  assert(type(bucket) == "string" and bucket ~= "", "Invalid bucket (missing or empty string)")
  assert(#bucket >= BUCKET_MIN_LEN and #bucket <= BUCKET_MAX_LEN, "Invalid bucket (unsafe length)")
  assert(bucket:match(BUCKET_PATTERN), "Invalid bucket (unsafe characters)")
  return bucket
end
local validate_key
validate_key = function(key, message)
  if message == nil then
    message = "Invalid key (missing or empty string)"
  end
  assert(type(key) == "string" and key ~= "", message)
  assert(not key:match("^/"), "Invalid key (unsafe path structure)")
  assert(not key:match("/$"), "Invalid key (unsafe path structure)")
  assert(not key:match("//"), "Invalid key (unsafe path structure)")
  for chunk in key:gmatch("[^/]+") do
    assert(chunk ~= "." and chunk ~= ".." and chunk:match(VALID_NAME_CHUNK), "Invalid key (unsafe characters)")
  end
  return key
end
local mkdir_p
mkdir_p = function(path)
  local current
  if path:match("^/") then
    current = "/"
  else
    current = ""
  end
  for part in path:gmatch("[^/]+") do
    current = current .. (((function()
      if current == "" or current == "/" then
        return ""
      else
        return "/"
      end
    end)()) .. part)
    local ok, err = lfs.mkdir(current)
    if not ok then
      local mode = lfs.attributes(current, "mode")
      assert(mode == "directory", err)
    end
  end
  return true
end
local file_stat
file_stat = function(path)
  local attr = lfs.attributes(path)
  if not (attr) then
    return nil
  end
  return attr.size, os.date("!%Y-%m-%dT%H:%M:%SZ", attr.modification)
end
local list_files
list_files = function(base_path)
  local results = { }
  local scan
  scan = function(dir, prefix)
    for entry in lfs.dir(dir) do
      local _continue_0 = false
      repeat
        if entry == "." or entry == ".." then
          _continue_0 = true
          break
        end
        local full = tostring(dir) .. "/" .. tostring(entry)
        local mode = lfs.attributes(full, "mode")
        if mode == "file" then
          table.insert(results, (function()
            if prefix == "" then
              return entry
            else
              return tostring(prefix) .. "/" .. tostring(entry)
            end
          end)())
        elseif mode == "directory" then
          scan(full, ((function()
            if prefix == "" then
              return entry
            else
              return tostring(prefix) .. "/" .. tostring(entry)
            end
          end)()))
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
  end
  scan(base_path, "")
  return results
end
local MockStorage
do
  local _class_0
  local _base_0 = {
    mock_headers = function(self, headers, ctx)
      return headers
    end,
    bucket = function(self, bucket)
      validate_bucket(bucket)
      return Bucket(bucket, self)
    end,
    _full_path = function(self, bucket, key)
      validate_bucket(bucket)
      validate_key(key)
      local dir
      if self.dir_name == "." then
        dir = ""
      else
        dir = self.dir_name .. "/"
      end
      return tostring(dir) .. tostring(bucket) .. "/" .. tostring(key)
    end,
    bucket_url = function(self, bucket, opts)
      if opts == nil then
        opts = { }
      end
      validate_bucket(bucket)
      if opts.scheme or opts.subdomain then
        local scheme = opts.scheme or "https"
        local base
        if self.url_prefix == "" then
          base = "localhost"
        else
          base = self.url_prefix
        end
        if opts.subdomain then
          return tostring(scheme) .. "://" .. tostring(bucket) .. "." .. tostring(base)
        else
          return tostring(scheme) .. "://" .. tostring(base) .. "/" .. tostring(bucket)
        end
      else
        local prefix
        if self.url_prefix == "" then
          prefix = ""
        else
          prefix = self.url_prefix .. "/"
        end
        return prefix .. (function()
          if self.dir_name == "." then
            return bucket
          else
            return tostring(self.dir_name) .. "/" .. tostring(bucket)
          end
        end)()
      end
    end,
    file_url = function(self, bucket, key, opts)
      validate_bucket(bucket)
      validate_key(key)
      if opts and (opts.scheme or opts.subdomain) then
        return tostring(self:bucket_url(bucket, opts)) .. "/" .. tostring(key)
      else
        local prefix
        if self.url_prefix == "" then
          prefix = ""
        else
          prefix = self.url_prefix .. "/"
        end
        return prefix .. self:_full_path(bucket, key)
      end
    end,
    get_service = function(self)
      local path = self.dir_name
      mkdir_p(path)
      local out = { }
      for entry in lfs.dir(path) do
        local _continue_0 = false
        repeat
          if entry == "." or entry == ".." then
            _continue_0 = true
            break
          end
          local full = tostring(path) .. "/" .. tostring(entry)
          if lfs.attributes(full, "mode") == "directory" then
            table.insert(out, {
              name = entry
            })
          end
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      table.sort(out, function(a, b)
        return a.name < b.name
      end)
      return out
    end,
    get_bucket = function(self, bucket)
      validate_bucket(bucket)
      local path = tostring(self.dir_name) .. "/" .. tostring(bucket)
      mkdir_p(path)
      local files = list_files(path)
      local out
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #files do
          local file = files[_index_0]
          local full_path = tostring(path) .. "/" .. tostring(file)
          local size, last_modified = file_stat(full_path)
          local _value_0 = {
            key = file,
            size = size,
            last_modified = last_modified
          }
          _accum_0[_len_0] = _value_0
          _len_0 = _len_0 + 1
        end
        out = _accum_0
      end
      table.sort(out, function(a, b)
        return a.key < b.key
      end)
      return out
    end,
    put_file_string = function(self, bucket, key, data, options)
      if options == nil then
        options = { }
      end
      validate_bucket(bucket)
      assert(not options.key, "key is not an option, but an argument")
      if type(data) == "table" then
        error("put_file_string interface has changed: key is now the second argument")
      end
      validate_key(key)
      assert(type(data) == "string", "expected string for data")
      local path = self:_full_path(bucket, key)
      local dir = path:match("(.+)/")
      if dir then
        mkdir_p(dir)
      end
      local f = assert(io.open(path, "w"))
      assert(f:write(data))
      f:close()
      return 200
    end,
    put_file = function(self, bucket, fname, options)
      if options == nil then
        options = { }
      end
      validate_bucket(bucket)
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
      local key = options.key or fname
      if options.key then
        do
          local _tbl_0 = { }
          for k, v in pairs(options) do
            if k ~= "key" then
              _tbl_0[k] = v
            end
          end
          options = _tbl_0
        end
      end
      return self:put_file_string(bucket, key, data, options)
    end,
    put_file_acl = function(self, bucket, key, acl)
      validate_bucket(bucket)
      validate_key(key)
      return error("Not implemented in MockStorage")
    end,
    copy_file = function(self, source_bucket, source_key, dest_bucket, dest_key, options)
      if options == nil then
        options = { }
      end
      validate_bucket(source_bucket)
      validate_key(source_key)
      validate_bucket(dest_bucket)
      validate_key(dest_key)
      local source_path = self:_full_path(source_bucket, source_key)
      local f = io.open(source_path)
      if not (f) then
        return nil, "File not found: " .. tostring(source_key)
      end
      local data = f:read("*a")
      f:close()
      return self:put_file_string(dest_bucket, dest_key, data)
    end,
    compose = function(self, bucket, key, source_keys, options)
      if options == nil then
        options = { }
      end
      validate_bucket(bucket)
      validate_key(key)
      assert(type(source_keys) == "table" and next(source_keys), "invalid source keys")
      local chunks = { }
      for _index_0 = 1, #source_keys do
        local key_obj = source_keys[_index_0]
        local name
        if type(key_obj) == "table" then
          name = key_obj.name
        else
          name = key_obj
        end
        assert(name, "missing source key name for compose")
        validate_key(name)
        local source_path = self:_full_path(bucket, name)
        local f = io.open(source_path)
        if not (f) then
          return nil, "File not found: " .. tostring(name)
        end
        local data = f:read("*a")
        f:close()
        table.insert(chunks, data)
      end
      return self:put_file_string(bucket, key, table.concat(chunks))
    end,
    delete_file = function(self, bucket, key)
      validate_bucket(bucket)
      validate_key(key, "Invalid key for deletion (missing or empty string)")
      local path = self:_full_path(bucket, key)
      if lfs.attributes(path, "mode") then
        os.remove(path)
        return 200
      else
        return nil, "File not found: " .. tostring(key)
      end
    end,
    get_file = function(self, bucket, key)
      validate_bucket(bucket)
      validate_key(key)
      local path = self:_full_path(bucket, key)
      local f = io.open(path)
      if not (f) then
        return nil, "File not found: " .. tostring(key)
      end
      local data = f:read("*a")
      f:close()
      local size, last_modified = file_stat(path)
      local code = 200
      local headers = {
        ["Content-length"] = #data,
        ["Last-modified"] = last_modified,
        ["x-goog-generation"] = "mock"
      }
      headers = self:mock_headers(headers, {
        method = "GET",
        bucket = bucket,
        key = key,
        path = path,
        size = size,
        last_modified = last_modified,
        code = code,
        data = data
      })
      return data, code, headers
    end,
    head_file = function(self, bucket, key)
      validate_bucket(bucket)
      validate_key(key)
      local path = self:_full_path(bucket, key)
      local f = io.open(path)
      if not (f) then
        return nil, "File not found: " .. tostring(key)
      end
      f:close()
      local size, last_modified = file_stat(path)
      local code = 200
      local headers = {
        ["Content-length"] = size,
        ["Last-modified"] = last_modified
      }
      headers = self:mock_headers(headers, {
        method = "HEAD",
        bucket = bucket,
        key = key,
        path = path,
        size = size,
        last_modified = last_modified,
        code = code
      })
      return "", code, headers
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, dir_name, url_prefix)
      if dir_name == nil then
        dir_name = "."
      end
      if url_prefix == nil then
        url_prefix = ""
      end
      self.dir_name, self.url_prefix = dir_name, url_prefix
    end,
    __base = _base_0,
    __name = "MockStorage"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  MockStorage = _class_0
end
return {
  MockStorage = MockStorage,
  validate_bucket = validate_bucket,
  validate_key = validate_key
}
