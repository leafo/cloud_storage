package = "cloud_storage"
version = "0.1.0-1"

source = {
  url = "git://github.com/leafo/cloud_storage.git",
  branch = "v0.1.0",
}

description = {
  summary = "Access Google Cloud Storage from Lua",
  license = "MIT",
  maintainer = "Leaf Corcoran <leafot@gmail.com>",
}

dependencies = {
  "lua >= 5.1",
  "luasocket",
  "lua-cjson",
  "mimetypes",
  "luacrypto",
  "date",
  "luaexpat",
}

build = {
  type = "builtin",
  modules = {
    ["cloud_storage.mock"] = "cloud_storage/mock.lua",
    ["cloud_storage.google"] = "cloud_storage/google.lua",
    ["cloud_storage.oauth"] = "cloud_storage/oauth.lua",
    ["cloud_storage.http"] = "cloud_storage/http.lua",
  }
}
