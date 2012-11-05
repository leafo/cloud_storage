url = require "socket.url"
mime = require "mime"

json = require "cjson"
crypto = require "crypto"

https = require "ssl.https"

param = (tbl) ->
  tuples = for k,v in pairs tbl
    "#{url.escape k}=#{url.escape v}"

  table.concat tuples, "&"

class OAuth
  auth_url: "https://accounts.google.com/o/oauth2/token"
  header: '{"alg":"RS256","typ":"JWT"}'

  new: (@client_email, @private_key) =>

  get_access_token: =>
    if not @access_token or os.time! >= @expires_at
      @refresh_access_token!

    @access_token

  refresh_access_token: =>
    time = os.time!
    jwt = @_make_jwt @client_email, @private_key

    req_params = param {
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer"
      assertion: jwt
    }

    res = assert https.request @auth_url, req_params
    res = json.decode res

    @expires_at = time + res.expires_in
    @access_token = res.access_token
    @access_token

  _make_jwt: (client_email, private_key) =>
    hr = 60*60
    claims = json.encode {
      iss: client_email
      aud: @auth_url
      scope: "https://www.googleapis.com/auth/devstorage.read_write"
      iat: os.time!
      exp: os.time! + hr
    }

    sig_input = mime.b64(@header) .. "." .. mime.b64(claims)

    dtype = "sha256WithRSAEncryption"
    private = assert crypto.pkey.read private_key, true

    signature = crypto.sign dtype, sig_input, private
    sig_input .. "." .. mime.b64(signature)

{ :OAuth }

