
oauth = require "cloud_storage.oauth"
google = require "cloud_storage.google"

TEST_KEY_PATH = "spec/test_key.pem"
TEST_KEY_PATH_JSON = "spec/test_key.json"

describe "cloud_storage", ->
  it "should create an oauth", ->
    o = oauth.OAuth "leaf@leafo.net", TEST_KEY_PATH
    storage = google.CloudStorage o, "111111111111"

  describe "oauth", ->
    local o
    before_each ->
      o = oauth.OAuth "leaf@leafo.net", TEST_KEY_PATH

    it "should make jwt", ->
      assert.truthy o\_make_jwt o.client_email, o.private_key

    describe "private key loading", ->
      it "should load private key from file", ->
        key = o\_private_key!
        assert.truthy key

      it "should load private key from string", ->
        key_content = assert(io.open(TEST_KEY_PATH))\read "*a"
        o\_load_private_key key_content
        key = o\_private_key!
        assert.truthy key

      it "should fail with invalid key file", ->
        bad_oauth = oauth.OAuth "leaf@leafo.net", "nonexistent.pem"
        assert.has_error(
          -> bad_oauth\_private_key!
        )

        -- invalid file type
        bad_oauth = oauth.OAuth "leaf@leafo.net", "spec/cloud_storage_spec.moon"
        assert.has_error(
          -> bad_oauth\_private_key!
        )

    describe "string signing", ->
      -- this should be deterministic since the key is stored in the test suite
      it "should sign string and return base64", ->
        signature = o\sign_string "test string"
        assert.same "Z1x1HRvpY9tWnf+O1HU3D+A7VNHY4LTem4YUORBS6r4rrbYjYhgUntEy9hfwoPeFyilBY4K6mGYctUBBnRAybcqWWDz68rmS0zR3ROy/pBfFGrcbRoFVwQnx/nVliqUH6+i3iPUE/S7haPh6b8O0yy3ltZBhuAYfZAinJiS4mVM=", signature

      it "should produce consistent signatures", ->
        sig1 = o\sign_string "consistent test"
        sig2 = o\sign_string "consistent test"
        assert.same sig1, sig2

    describe "token management", ->
      local http_requests
      local snapshot

      json = require "cjson"

      before_each ->
        snapshot = assert\snapshot!
        http_requests = {}

        http = require("cloud_storage.http")
        stub(http, "get", {
          request: (url, params) ->
            table.insert http_requests, {url: url, params: params}
            return json.encode {
              expires_in: 3600
              access_token: "mock-access-token-123"
            }
        })

      after_each ->
        snapshot\revert!

      it "should refresh access token", ->
        token = o\refresh_access_token!
        assert.same "mock-access-token-123", token
        assert.same "mock-access-token-123", o.access_token
        assert.truthy o.expires_at

      it "should make proper JWT request format", ->
        o\refresh_access_token!
        assert.same 1, #http_requests
        request = http_requests[1]
        assert.same o.auth_url, request.url
        assert.truthy request.params\find "grant_type"
        assert.truthy request.params\find "assertion"

      it "should cache tokens and not refresh when valid", ->
        o.access_token = "existing-token"
        o.expires_at = os.time! + 1000

        token = o\get_access_token!
        assert.same "existing-token", token
        assert.same 0, #http_requests

      it "should refresh expired tokens", ->
        o.access_token = "old-token"
        o.expires_at = os.time! - 100

        token = o\get_access_token!
        assert.same "mock-access-token-123", token
        assert.same 1, #http_requests

      describe "with auth errors", ->
        before_each ->
          http = require("cloud_storage.http")
          stub(http, "get", {
            request: (url, params) ->
              table.insert http_requests, {url: url, params: params}
              return json.encode { error: "invalid_grant" }
          })

        it "should handle auth errors", ->
          assert.has_error(
            -> o\refresh_access_token!
            "Failed auth: invalid_grant"
          )

    describe "jwt creation", ->
      it "should create valid jwt format", ->
        jwt = o\_make_jwt o.client_email, o\_private_key!
        parts = [part for part in jwt\gmatch "[^%.]+"]
        assert.same 3, #parts

      it "should include proper claims", ->
        jwt = o\_make_jwt o.client_email, o\_private_key!
        header_b64, claims_b64, sig = jwt\match "([^%.]+)%.([^%.]+)%.([^%.]+)"

        mime = require "mime"
        json = require "cjson"

        assert.truthy claims_b64, "claims part should be present"
        claims_str = mime.unb64 claims_b64
        assert.truthy claims_str, "decoded claims should not be nil"
        claims = json.decode claims_str
        assert.same o.client_email, claims.iss
        assert.same o.auth_url, claims.aud
        assert.same o.scope.full_control, claims.scope
        assert.truthy claims.iat
        assert.truthy claims.exp

  describe "with storage", ->
    local storage

    before_each  ->
      o = oauth.OAuth "leaf@leafo.net", TEST_KEY_PATH
      storage = google.CloudStorage o, "111111111111"

    it "generates bucket url", ->
      assert.same "https://commondatastorage.googleapis.com/my-bucket", storage\bucket_url "my-bucket"
      assert.same "http://my-bucket.commondatastorage.googleapis.com", storage\bucket_url "my-bucket", {
        scheme: "http"
        subdomain: true
      }

    it "generates file url", ->
      assert.same "https://commondatastorage.googleapis.com/my-bucket/pics/leafo.png", storage\file_url "my-bucket", "pics/leafo.png"
      assert.same "http://my-bucket.commondatastorage.googleapis.com/pics/leafo.png", storage\file_url "my-bucket", "pics/leafo.png", {
        scheme: "http"
        subdomain: true
      }

    it "should create signed url", ->
      url = storage\signed_url "thebucket", "hello.txt", 10000
      assert.same "https://commondatastorage.googleapis.com/thebucket/hello.txt?GoogleAccessId=leaf@leafo.net&Expires=10000&Signature=W8kzLHy1p0wAEjR%2FdPb9VeJ%2B%2Bm154%2BEJFBo47vdWmVGNsFFDo6n%2Bhnpy17bYQH9xF8H2lABp%2BJyn%2B0ViJimIDZwiQ%2FtPe1bTTrXVA1Uzucu7tdH29M60mnwRCyxYKQqoVkDhwki1HuUPluRRVndkrdfU1J8Cq8qIEaXcGDzt3O4=", url

    it "should create signed url with options", ->
      url = storage\signed_url "thebucket", "hello.txt", 10000, {
        headers: {
          "Content-Disposition": "attachment" -- this header is ignored
          "x-goog-resumable": "start"
        }
        verb: "POST"
        scheme: "http"
      }
      assert.same 'http://commondatastorage.googleapis.com/thebucket/hello.txt?GoogleAccessId=leaf@leafo.net&Expires=10000&Signature=GwFHuaLI48MuvwD7YsoPlF3TMe1oZg1hFjdb37pzw65HKtNshW87gzCY7rXjYX4HmFr%2FYHJKZwQ4WQo30IGYYjG9ccJPAJaySYUW7JWkrk34h%2BlWYyhX0kq8ayEnCL3y96UJc3%2F0oizsUoIxxPek6KyzaWxEENWQQQVRxD6q2g0=', url

    it "should encode file with funky chars in it", ->
      url = storage\signed_url "thebucket", "he[f]llo#one.txt", 10000
      assert.falsy url\find "#", 1, true
      assert.falsy url\find "]", 1, true
      assert.falsy url\find "[", 1, true

    it "should encode even more chars", ->
      import url_encode_key from require "cloud_storage.google"
      assert.same [[%21_@_$_%5E_%2A_%28_%29_+_=_%5D_%5B_\_/_._,_%27_%22_%25]],
        url_encode_key [[!_@_$_^_*_(_)_+_=_]_[_\_/_._,_'_"_%]]

    it "should canonicalize headers", ->
      headers = {}
      headers["x-goog-acl"] = "project-private"
      headers["x-goog-meta-hello"] = "hella\nhelli"
      headers["x-goog-encryption-key"] = "best"
      headers["x-goog-encryption-key-sha256"] = "dad"
      headers["Content-Disposition"] = "attachment"
      headers["Content-Length"] = 0
      assert.same "x-goog-acl:project-private\nx-goog-meta-hello:hella helli", storage\canonicalize_headers headers

    it "creates upload url", ->
      url, params = assert storage\upload_url "thebucket", "hello.txt", {
        expires: 10000
        filename: "bart.zip"
        size_limit: 1024
        acl: "public-read"
        success_action_redirect: "http://leafo.net"
      }

      assert.same "https://thebucket.commondatastorage.googleapis.com", url

      assert.same {
        "Content-Disposition": "attachment; filename=\"bart.zip\"",
        GoogleAccessId: "leaf@leafo.net",
        signature: "BtimAyE8GUOcCRE3ie7/6AjAuVXn/urTro69vhMB35oOPzlWT23iguL9mi2D7KQ0kAP+6uJL9u3Dr7xtLgMhMFDFWje9GZ9VdZlEBELjyB+MWrXZm1fvMcbr8WfWAK/JCezEe3keOdXpD5w5kV6lydVKZWVapUNf0u2CD1WtCG0=",
        success_action_redirect: "http://leafo.net",
        policy: "eyJleHBpcmF0aW9uIjoiMTk3MC0wMS0wMVQwMjo0Njo0MFoiLCJjb25kaXRpb25zIjpbeyJhY2wiOiJwdWJsaWMtcmVhZCJ9LHsiYnVja2V0IjoidGhlYnVja2V0In0sWyJlcSIsIiRrZXkiLCJoZWxsby50eHQiXSxbImVxIiwiJENvbnRlbnQtRGlzcG9zaXRpb24iLCJhdHRhY2htZW50OyBmaWxlbmFtZT1cImJhcnQuemlwXCIiXSxbImNvbnRlbnQtbGVuZ3RoLXJhbmdlIiwwLDEwMjRdLHsic3VjY2Vzc19hY3Rpb25fcmVkaXJlY3QiOiJodHRwOlwvXC9sZWFmby5uZXQifV19",
        key:"hello.txt",
        acl: "public-read"
      }, params

      mime = require "mime"
      json = require "cjson"

      policy = json.decode (mime.unb64 params.policy)
      assert.same {
        expiration: "1970-01-01T02:46:40Z"
        conditions: {
          { acl: "public-read" }
          { bucket: "thebucket" }
          { "eq", "$key", "hello.txt" }
          { "eq", "$Content-Disposition", "attachment; filename=\"bart.zip\"" }
          { "content-length-range", 0, 1024 }
          { success_action_redirect: "http://leafo.net" }
        }
      }, policy

    describe "with http", ->
      local http_requests
      local snapshot

      json = require "cjson"

      before_each ->
        snapshot = assert\snapshot!

      after_each ->
        snapshot\revert!

      before_each ->
        http_requests = {}

        http = require("cloud_storage.http")
        stub(http, "get", {
          request: (r) ->
            -- let the token request go through
            if r == "https://accounts.google.com/o/oauth2/token"
              return json.encode {
                expires_in: 100000
                access_token: "my-fake-access-token"
              }

            dupe = {k,v for k,v in pairs r}
            if dupe.source
              dupe.source = dupe.source!
            dupe.sink = nil
            dupe.headers.Date = nil
            table.insert http_requests, dupe
        })

      it "put_file_string", ->
        storage\put_file_string "mybucket", "hello.txt", "the contents", {
          acl: "public-read"
        }

        assert.same http_requests, {
          {
            url: "https://storage.googleapis.com/mybucket/hello.txt"
            method: "PUT"
            source: "the contents"
            headers: {
              "Content-length": 12
              "x-goog-acl": "public-read"
              "x-goog-api-version": 2
              "x-goog-project-id": "111111111111"
              Authorization: "OAuth my-fake-access-token"
            }
          }
        }


      it "get_bucket", ->
        storage\get_bucket "mybucket"
        assert.same {
          {
            url: "https://storage.googleapis.com/mybucket"
            method: "GET"
            headers: {
              "x-goog-api-version": 2
              "x-goog-project-id": "111111111111"
              Authorization: "OAuth my-fake-access-token"
            }
          }
        }, http_requests

      it "get_file", ->
        storage\get_file "mybucket", "source/my-file.lua"
        assert.same {
          {
            url: "https://storage.googleapis.com/mybucket/source%2fmy%2dfile%2elua"
            method: "GET"
            headers: {
              "x-goog-api-version": 2
              "x-goog-project-id": "111111111111"
              Authorization: "OAuth my-fake-access-token"
            }
          }
        }, http_requests

      it "get_file fails with empty key", ->
        assert.has_error(
          -> storage\get_file "mybucket", ""
          "Invalid key (missing or empty string)"
        )
        assert.same { }, http_requests

      it "get_file fails with missing key", ->
        assert.has_error(
          -> storage\get_file "mybucket"
          "Invalid key (missing or empty string)"
        )
        assert.same { }, http_requests

      it "copy_file", ->
        storage\copy_file "from_bucket", "input/a.txt", "to_bucket", "output/b.txt", {
          acl: "private"
        }

        assert.same {
          {
            url: "https://storage.googleapis.com/to_bucket/output%2fb%2etxt"
            method: "PUT"
            headers: {
              "Content-length": "0"
              "x-goog-api-version": 2
              "x-goog-acl": "private"
              "x-goog-copy-source": "/from_bucket/input/a.txt"
              "x-goog-project-id": "111111111111"
              Authorization: "OAuth my-fake-access-token"
            }
          }
        }, http_requests

      it "delete_file", ->
        storage\delete_file "mybucket", "source/my-pic..png"
        assert.same {
          {
            url: "https://storage.googleapis.com/mybucket/source%2fmy%2dpic%2e%2epng"
            method: "DELETE"
            headers: {
              "x-goog-api-version": 2
              "x-goog-project-id": "111111111111"
              Authorization: "OAuth my-fake-access-token"
            }
          }
        }, http_requests

      it "delete_file fails with empty string key", ->
        assert.has_error(
          -> storage\delete_file "mybucket", ""
          "Invalid key for deletion (missing or empty string)"
        )

        assert.same {}, http_requests

      it "delete_file fails with missing string key", ->
        assert.has_error(
          -> storage\delete_file "mybucket"
          "Invalid key for deletion (missing or empty string)"
        )

        assert.same {}, http_requests

  describe "with storage from json key", ->
    local storage

    before_each  ->
      storage = google.CloudStorage\from_json_key_file TEST_KEY_PATH_JSON

    it "should create signed url", ->
      url = storage\signed_url "thebucket", "hello.txt", 10000
      assert.same "https://commondatastorage.googleapis.com/thebucket/hello.txt?GoogleAccessId=leaf@leafo.net&Expires=10000&Signature=W8kzLHy1p0wAEjR%2FdPb9VeJ%2B%2Bm154%2BEJFBo47vdWmVGNsFFDo6n%2Bhnpy17bYQH9xF8H2lABp%2BJyn%2B0ViJimIDZwiQ%2FtPe1bTTrXVA1Uzucu7tdH29M60mnwRCyxYKQqoVkDhwki1HuUPluRRVndkrdfU1J8Cq8qIEaXcGDzt3O4=", url
