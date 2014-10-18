
oauth = require "cloud_storage.oauth"
google = require "cloud_storage.google"

TEST_KEY_PATH = "spec/test_key.pem"

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


  describe "with storage", ->
    local storage

    before_each  ->
      o = oauth.OAuth "leaf@leafo.net", TEST_KEY_PATH
      storage = google.CloudStorage o, "111111111111"


    it "should create signed url", ->
      url = storage\signed_url "thebucket", "hello.txt", 10000
      assert.same "http://commondatastorage.googleapis.com/thebucket/hello.txt?GoogleAccessId=leaf@leafo.net&Expires=10000&Signature=W8kzLHy1p0wAEjR%2FdPb9VeJ%2B%2Bm154%2BEJFBo47vdWmVGNsFFDo6n%2Bhnpy17bYQH9xF8H2lABp%2BJyn%2B0ViJimIDZwiQ%2FtPe1bTTrXVA1Uzucu7tdH29M60mnwRCyxYKQqoVkDhwki1HuUPluRRVndkrdfU1J8Cq8qIEaXcGDzt3O4=", url

    it "should encode file with funky chars in it", ->
      url = storage\signed_url "thebucket", "he[f]llo#one.txt", 10000
      assert.falsy url\find "#", 1, true
      assert.falsy url\find "]", 1, true
      assert.falsy url\find "[", 1, true
