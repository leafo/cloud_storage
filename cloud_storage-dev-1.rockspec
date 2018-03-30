package = "cloud_storage"
version = "dev-1"

source = {
  url = "git://github.com/leafo/cloud_storage.git",
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
  "luaossl",
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
