package = "cloud_storage"
version = "dev-1"

source = {
  url = "https://github.com/leafo/cloud_storage.git",
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
}

build = {
	type = "builtin",
	modules = {
		["cloud_storage.oauth"] = "cloud_storage/oauth.lua",
		["cloud_storage.google"] = "cloud_storage/google.lua",
	}
}
