mock = require "cloud_storage.mock"

TEST_ROOT = "spec/tmp/mock_storage"

list_keys = (items) ->
  out = [item.key for item in *items]
  table.sort out
  out

cleanup_test_root = ->
  os.execute "rm -rf '#{TEST_ROOT}'"
  os.execute "mkdir -p '#{TEST_ROOT}'"

describe "mock_storage", ->
  local storage
  local bucket

  before_each ->
    cleanup_test_root!
    storage = mock.MockStorage TEST_ROOT, "static"
    bucket = storage\bucket "my_bucket"

  it "builds full paths", ->
    assert.same "#{TEST_ROOT}/dad_bucket/eat/my/sucks", storage\_full_path "dad_bucket", "eat/my/sucks"
    assert.same "nobucket/hello.world", mock.MockStorage!\_full_path "nobucket", "hello.world"

  it "lists uploaded files with metadata", ->
    assert.same 200, bucket\put_file_string "some_file.txt", "this is a file"
    assert.same 200, bucket\put_file_string "something/with/path.cpp", "yeah"

    listing = bucket\list!
    assert.same {
      "some_file.txt"
      "something/with/path.cpp"
    }, list_keys listing

    by_key = {}
    by_key[item.key] = item for item in *listing
    assert.same 14, by_key["some_file.txt"].size
    assert.same 4, by_key["something/with/path.cpp"].size
    assert.truthy by_key["some_file.txt"].last_modified\match "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"
    assert.truthy by_key["something/with/path.cpp"].last_modified\match "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"

  it "writes two files under a shared directory prefix", ->
    assert.same 200, bucket\put_file_string "common/path/one.txt", "first"
    assert.same 200, bucket\put_file_string "common/path/two.txt", "second"

    assert.same {
      "common/path/one.txt"
      "common/path/two.txt"
    }, list_keys bucket\list!

    one_body, one_code = storage\get_file "my_bucket", "common/path/one.txt"
    two_body, two_code = storage\get_file "my_bucket", "common/path/two.txt"
    assert.same "first", one_body
    assert.same "second", two_body
    assert.same 200, one_code
    assert.same 200, two_code

  it "generates bucket and file urls", ->
    assert.same "static/#{TEST_ROOT}/my_bucket", storage\bucket_url "my_bucket"
    assert.same "static/#{TEST_ROOT}/my_bucket/something/with/path.cpp", bucket\file_url "something/with/path.cpp"
    assert.same "http://my_bucket.static", storage\bucket_url "my_bucket", {
      scheme: "http"
      subdomain: true
    }
    assert.same "http://static/my_bucket", storage\bucket_url "my_bucket", {
      scheme: "http"
    }
    assert.same "http://my_bucket.static/cool/thing.lua", storage\file_url "my_bucket", "cool/thing.lua", {
      scheme: "http"
      subdomain: true
    }

  it "uploads file from disk with key override", ->
    source_path = "#{TEST_ROOT}/source/hi.lua"
    os.execute "mkdir -p '#{TEST_ROOT}/source'"
    with io.open source_path, "w"
      \write "print('hi')"
      \close!

    assert.same 200, bucket\put_file source_path, key: "cool/thing.lua"
    assert.same {"cool/thing.lua"}, list_keys bucket\list!

  it "lists buckets from get_service", ->
    assert.same {}, storage\get_service!
    bucket\put_file_string "hello.txt", "world"
    assert.same {
      { name: "my_bucket" }
    }, storage\get_service!

  it "deletes files and ignores deleting non-existent keys", ->
    bucket\put_file_string "some_file.txt", "this is a file"
    bucket\put_file_string "cool/thing.lua", "thing"

    assert.same 200, bucket\delete_file "some_file.txt"
    assert.same 200, bucket\delete_file "cool/does_not_exist.txt"

    assert.same {"cool/thing.lua"}, list_keys bucket\list!

  it "gets file content", ->
    bucket\put_file_string "some_file.txt", "this is a file"
    body, code, headers = storage\get_file "my_bucket", "some_file.txt"
    assert.same "this is a file", body
    assert.same 200, code
    assert.same 14, headers["Content-length"]
    assert.same "mock", headers["x-goog-generation"]
    assert.truthy headers["Last-modified"]\match "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"

  it "heads file metadata", ->
    bucket\put_file_string "some_file.txt", "this is a file"
    body, code, headers = storage\head_file "my_bucket", "some_file.txt"
    assert.same "", body
    assert.same 200, code
    assert.same 14, headers["Content-length"]
    assert.truthy headers["Last-modified"]\match "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"

  it "returns not found for missing object reads", ->
    assert.same nil, (storage\get_file "my_bucket", "missing.txt")
    assert.same nil, (storage\head_file "my_bucket", "missing.txt")

  it "validates key arguments consistently", ->
    assert.has_error(
      -> storage\put_file_string "my_bucket", "", "x"
      "Invalid key (missing or empty string)"
    )
    assert.has_error(
      -> storage\get_file "my_bucket", ""
      "Invalid key (missing or empty string)"
    )
    assert.has_error(
      -> storage\head_file "my_bucket", ""
      "Invalid key (missing or empty string)"
    )
    assert.has_error(
      -> storage\delete_file "my_bucket", ""
      "Invalid key for deletion (missing or empty string)"
    )
