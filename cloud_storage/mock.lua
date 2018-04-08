local Bucket
Bucket = require("cloud_storage.google").Bucket
local shell_escape
shell_escape = function(str)
  return str:gsub("'", "''")
end
local execute
execute = function(cmd)
  local proc = io.popen(cmd)
  local out = proc:read("*a")
  proc:close()
  return out:match("^(.-)%s*$")
end
local MockStorage
do
  local _class_0
  local _base_0 = {
    bucket = function(self, bucket)
      return Bucket(bucket, self)
    end,
    _full_path = function(self, bucket, key)
      local dir
      if self.dir_name == "." then
        dir = ""
      else
        dir = self.dir_name .. "/"
      end
      return tostring(dir) .. tostring(bucket) .. "/" .. tostring(key)
    end,
    file_url = function(self, bucket, key)
      local prefix
      if self.url_prefix == "" then
        prefix = ""
      else
        prefix = self.url_prefix .. "/"
      end
      return prefix .. self:_full_path(bucket, key)
    end,
    get_service = function(self)
      return error("Not implemented")
    end,
    get_bucket = function(self, bucket)
      local path = tostring(self.dir_name) .. "/" .. tostring(bucket)
      execute("mkdir -p '" .. tostring(shell_escape(path)) .. "'")
      local escaped_path = "$(echo '" .. tostring(shell_escape(path)) .. "' | sed -e 's/[\\/&]/\\\\&/g')"
      local cmd = 'find "' .. shell_escape(path) .. '" -type f | sed -e "s/^' .. escaped_path .. '//"'
      local files = execute(cmd)
      return (function()
        local _accum_0 = { }
        local _len_0 = 1
        for file in files:gmatch("[^\n]+") do
          _accum_0[_len_0] = {
            key = file:match("/?(.*)")
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()
    end,
    put_file_string = function(self, bucket, key, data, options)
      if options == nil then
        options = { }
      end
      assert(not options.key, "key is not an option, but an argument")
      if type(data) == "table" then
        error("put_file_string interface has changed: key is now the second argument")
      end
      assert(key, "missing key")
      assert(type(data) == "string", "expected string for data")
      local path = self:_full_path(bucket, key)
      local dir = execute("dirname '" .. tostring(shell_escape(path)) .. "'")
      execute("mkdir -p '" .. tostring(shell_escape(dir)) .. "'")
      do
        local _with_0 = io.open(path, "w")
        _with_0:write(data)
        _with_0:close()
      end
      return 200
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
      return self:put_file_string(bucket, data, options)
    end,
    delete_file = function(self, bucket, key)
      local path = self:_full_path(bucket, key)
      os.execute("[ -a '" .. tostring(shell_escape(path)) .. "' ] && rm '" .. tostring(shell_escape(path)) .. "'")
      return 200
    end,
    get_file = function(self, bucket, key)
      return error("not implemented")
    end,
    head_file = function(self, bucket, key)
      return error("Not implemented")
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
if ... == "test" then
  local moon = require("moon")
  local s = MockStorage("test_storage", "static")
  print(s:_full_path("dad_bucket", "eat/my/sucks"))
  print(MockStorage():_full_path("nobucket", "hello.world"))
  print()
  local b = s:bucket("my_bucket")
  b:put_file_string("this is a file", {
    key = "some_file.txt"
  })
  b:put_file_string("yeah", {
    key = "something/with/path.cpp"
  })
  b:put_file("hi.lua", {
    key = "cool/thing.lua"
  })
  moon.p(b:list())
  b:delete_file("some_file.txt")
  b:delete_file("cool/does_not_exist.txt")
  moon.p(b:list())
  print(b:file_url("cool/does_not_exist.txt"))
end
return {
  MockStorage = MockStorage
}
