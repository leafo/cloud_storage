url = require "socket.url"
mime = require "mime"
json = require "cjson"

pkey = require "openssl.pkey"
digest = require "openssl.digest"

h = require"cloud_storage.http"

param = (tbl) ->
  tuples = for k,v in pairs tbl
    "#{url.escape k}=#{url.escape v}"

  table.concat tuples, "&"

class OAuth
  auth_url: "https://accounts.google.com/o/oauth2/token"
  header: '{"alg":"RS256","typ":"JWT"}'
  digest_type: "sha256WithRSAEncryption"

  scope: {
    read_only: "https://www.googleapis.com/auth/devstorage.read_only"
    read_write: "https://www.googleapis.com/auth/devstorage.read_write"
    full_control: "https://www.googleapis.com/auth/devstorage.full_control"
  }

  new: (@client_email, @private_key_file) =>

  get_access_token: =>
    if not @access_token or os.time! >= @expires_at
      @refresh_access_token!

    @access_token

  refresh_access_token: =>
    http = h.get!

    time = os.time!
    jwt = @_make_jwt @client_email, @private_key

    req_params = param {
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer"
      assertion: jwt
    }

    res = assert http.request @auth_url, req_params
    res = json.decode res

    if res.error
      error "Failed auth: #{res.error}"

    @expires_at = time + res.expires_in
    @access_token = res.access_token
    @access_token

  sign_string: (string) =>
    d = assert digest.new @digest_type
    key = @_private_key!
    d\update string
    (mime.b64 assert key\sign d)

  _private_key: =>
    with key = assert pkey.new io.open(@private_key_file)\read "*a"
      @_private_key = -> key

  _make_jwt: (client_email, private_key) =>
    hr = 60*60
    claims = json.encode {
      iss: client_email
      aud: @auth_url
      scope: @scope.full_control
      iat: os.time!
      exp: os.time! + hr
    }

    sig_input = mime.b64(@header) .. "." .. mime.b64(claims)
    signature = @sign_string sig_input

    sig_input .. "." .. signature

{ :OAuth }

