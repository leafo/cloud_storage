mock = require "cloud_storage.mock"
validate_bucket = mock.validate_bucket
validate_key = mock.validate_key

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

  it "put_file_acl is explicitly not implemented", ->
    bucket\put_file_string "some_file.txt", "this is a file"
    assert.has_error(
      -> storage\put_file_acl "my_bucket", "some_file.txt", "private"
      "Not implemented in MockStorage"
    )

  it "copies files across buckets", ->
    assert.same 200, storage\put_file_string "source_bucket", "path/from.txt", "copy me"
    assert.same 200, storage\copy_file "source_bucket", "path/from.txt", "dest_bucket", "path/to.txt"

    body, code = storage\get_file "dest_bucket", "path/to.txt"
    assert.same "copy me", body
    assert.same 200, code

  it "copy_file returns nil for missing source", ->
    copied, err = storage\copy_file "source_bucket", "missing.txt", "dest_bucket", "out.txt"
    assert.same nil, copied
    assert.same "File not found: missing.txt", err

  it "composes files in order", ->
    storage\put_file_string "my_bucket", "part1.txt", "hello "
    storage\put_file_string "my_bucket", "part2.txt", "world"
    storage\put_file_string "my_bucket", "part3.txt", "!"

    assert.same 200, storage\compose "my_bucket", "joined.txt", {
      "part1.txt"
      { name: "part2.txt" }
      "part3.txt"
    }

    body, code = storage\get_file "my_bucket", "joined.txt"
    assert.same "hello world!", body
    assert.same 200, code

  it "compose validates source list and source names", ->
    assert.has_error(
      -> storage\compose "my_bucket", "joined.txt", {}
      "invalid source keys"
    )
    assert.has_error(
      -> storage\compose "my_bucket", "joined.txt", {
        { generation: "123" }
      }
      "missing source key name for compose"
    )

  it "compose returns nil when a source file is missing", ->
    storage\put_file_string "my_bucket", "part1.txt", "hello "
    out, err = storage\compose "my_bucket", "joined.txt", {
      "part1.txt"
      "missing.txt"
    }
    assert.same nil, out
    assert.same "File not found: missing.txt", err

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
    assert.same nil, (bucket\delete_file "cool/does_not_exist.txt")

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

  it "routes response headers through mock_headers hook", ->
    bucket\put_file_string "some_file.txt", "this is a file"
    seen = {}
    storage.mock_headers = (self, headers, ctx) ->
      table.insert seen, {
        method: ctx.method
        bucket: ctx.bucket
        key: ctx.key
        path: ctx.path
        size: ctx.size
        code: ctx.code
        has_data: ctx.data != nil
      }
      headers["x-test-hook"] = "yes-#{ctx.method}"
      headers

    get_body, get_code, get_headers = storage\get_file "my_bucket", "some_file.txt"
    assert.same "this is a file", get_body
    assert.same 200, get_code
    assert.same "yes-GET", get_headers["x-test-hook"]

    head_body, head_code, head_headers = storage\head_file "my_bucket", "some_file.txt"
    assert.same "", head_body
    assert.same 200, head_code
    assert.same "yes-HEAD", head_headers["x-test-hook"]

    assert.same {
      {
        method: "GET"
        bucket: "my_bucket"
        key: "some_file.txt"
        path: "#{TEST_ROOT}/my_bucket/some_file.txt"
        size: 14
        code: 200
        has_data: true
      }
      {
        method: "HEAD"
        bucket: "my_bucket"
        key: "some_file.txt"
        path: "#{TEST_ROOT}/my_bucket/some_file.txt"
        size: 14
        code: 200
        has_data: false
      }
    }, seen

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

  it "rejects unsafe bucket and key names", ->
    assert.has_error(
      -> storage\bucket "../bucket"
      "Invalid bucket (unsafe characters)"
    )
    assert.has_error(
      -> storage\get_bucket "bad/bucket"
      "Invalid bucket (unsafe characters)"
    )

    assert.has_error(
      -> storage\put_file_string "my_bucket", "../escape.txt", "x"
      "Invalid key (unsafe characters)"
    )
    assert.has_error(
      -> storage\put_file_string "my_bucket", "a//b.txt", "x"
      "Invalid key (unsafe path structure)"
    )
    assert.has_error(
      -> storage\get_file "my_bucket", "a/$bad.txt"
      "Invalid key (unsafe characters)"
    )

describe "mock_storage validators", ->
  it "accepts valid bucket names", ->
    valid = {
      "my-bucket"
      "bucket_1"
      "bucket.name"
      "z9-_a"
      "abc"
      "a" .. ("b"\rep 61) .. "z"
    }

    for bucket in *valid
      assert.same bucket, validate_bucket bucket

  it "rejects invalid bucket names", ->
    invalid = {
      nil
      ""
      "ab"
      "a" .. ("b"\rep 62) .. "z"
      "."
      ".."
      "A"
      "Bucket"
      "my/bucket"
      "with space"
      "dollar$"
      "bucket:bad"
      "-start"
      "end-"
      "_start"
      "end_"
      ".start"
      "end."
    }

    for bucket in *invalid
      assert.has_error(
        -> validate_bucket bucket
      )

  it "accepts valid keys", ->
    valid = {
      "a"
      "a.txt"
      "folder/file.txt"
      "folder_1/sub-folder/file.name-01"
      "A/B/C"
      "0/9/_/dot.name-"
    }

    for key in *valid
      assert.same key, validate_key key

  it "rejects invalid key path structures", ->
    invalid = {
      nil
      ""
      "/leading.txt"
      "trailing.txt/"
      "double//slash.txt"
      "."
      ".."
      "./file.txt"
      "../file.txt"
      "folder/./file.txt"
      "folder/../file.txt"
    }

    for key in *invalid
      assert.has_error(
        -> validate_key key
      )

  it "rejects invalid key characters", ->
    invalid = {
      "space name.txt"
      "dollar$.txt"
      "semi;colon.txt"
      "quote\".txt"
      "single'.txt"
      "tab\tname.txt"
      "colon:name.txt"
      "folder/inv@lid.txt"
    }

    for key in *invalid
      assert.has_error(
        -> validate_key key
        "Invalid key (unsafe characters)"
      )

  it "uses custom missing-key error message", ->
    assert.has_error(
      -> validate_key "", "Custom missing key"
      "Custom missing key"
    )
