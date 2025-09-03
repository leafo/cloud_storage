local _http
local default
default = function()
  return require("socket.http")
end
local get
get = function()
  if not (_http) then
    _http = default()
  end
  return _http
end
local set
set = function(http)
  _http = http
end
return {
  get = get,
  set = set
}
