
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


