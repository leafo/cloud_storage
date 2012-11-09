local url = require("socket.url")
local mime = require("mime")
local json = require("cjson")
local crypto = require("crypto")
local h = require("cloud_storage.http")
local param
param = function(tbl)
  local tuples = (function()
    local _accum_0 = { }
    local _len_0 = 0
    for k, v in pairs(tbl) do
      local _value_0 = tostring(url.escape(k)) .. "=" .. tostring(url.escape(v))
      if _value_0 ~= nil then
        _len_0 = _len_0 + 1
        _accum_0[_len_0] = _value_0
      end
    end
    return _accum_0
  end)()
  return table.concat(tuples, "&")
end
local OAuth
do
  local _parent_0 = nil
  local _base_0 = {
    auth_url = "https://accounts.google.com/o/oauth2/token",
    header = '{"alg":"RS256","typ":"JWT"}',
    scope = {
      read_only = "https://www.googleapis.com/auth/devstorage.read_only",
      read_write = "https://www.googleapis.com/auth/devstorage.read_write",
      full_control = "https://www.googleapis.com/auth/devstorage.full_control"
    },
    get_access_token = function(self)
      if not self.access_token or os.time() >= self.expires_at then
        self:refresh_access_token()
      end
      return self.access_token
    end,
    refresh_access_token = function(self)
      local http = h.get()
      local time = os.time()
      local jwt = self:_make_jwt(self.client_email, self.private_key)
      local req_params = param({
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion = jwt
      })
      local res = assert(http.request(self.auth_url, req_params))
      res = json.decode(res)
      if res.error then
        error("Failed auth: " .. tostring(res.error))
      end
      self.expires_at = time + res.expires_in
      self.access_token = res.access_token
      return self.access_token
    end,
    _make_jwt = function(self, client_email, private_key)
      local hr = 60 * 60
      local claims = json.encode({
        iss = client_email,
        aud = self.auth_url,
        scope = self.scope.full_control,
        iat = os.time(),
        exp = os.time() + hr
      })
      local sig_input = mime.b64(self.header) .. "." .. mime.b64(claims)
      local dtype = "sha256WithRSAEncryption"
      local private = assert(crypto.pkey.read(private_key, true))
      local signature = crypto.sign(dtype, sig_input, private)
      return sig_input .. "." .. mime.b64(signature)
    end
  }
  _base_0.__index = _base_0
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self, client_email, private_key)
      self.client_email, self.private_key = client_email, private_key
    end,
    __base = _base_0,
    __name = "OAuth",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil and _parent_0 then
        return _parent_0[name]
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  OAuth = _class_0
end
return {
  OAuth = OAuth
}
