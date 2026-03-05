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

  it "lists uploaded files and file_url", ->
    assert.same 200, bucket\put_file_string "some_file.txt", "this is a file"
    assert.same 200, bucket\put_file_string "something/with/path.cpp", "yeah"

    assert.same {
      "some_file.txt"
      "something/with/path.cpp"
    }, list_keys bucket\list!

    assert.same "static/#{TEST_ROOT}/my_bucket/something/with/path.cpp", bucket\file_url "something/with/path.cpp"

  it "uploads file from disk with key override", ->
    source_path = "#{TEST_ROOT}/source/hi.lua"
    os.execute "mkdir -p '#{TEST_ROOT}/source'"
    with io.open source_path, "w"
      \write "print('hi')"
      \close!

    assert.same 200, bucket\put_file source_path, key: "cool/thing.lua"
    assert.same {"cool/thing.lua"}, list_keys bucket\list!

  it "deletes files and ignores deleting non-existent keys", ->
    bucket\put_file_string "some_file.txt", "this is a file"
    bucket\put_file_string "cool/thing.lua", "thing"

    assert.same 200, bucket\delete_file "some_file.txt"
    assert.same 200, bucket\delete_file "cool/does_not_exist.txt"

    assert.same {"cool/thing.lua"}, list_keys bucket\list!

  it "get_service is not implemented", ->
    assert.has_error(
      -> storage\get_service!
      "Not implemented"
    )

  it "get_file is not implemented", ->
    assert.has_error(
      -> storage\get_file "my_bucket", "some_file.txt"
      "not implemented"
    )

  it "head_file is not implemented", ->
    assert.has_error(
      -> storage\head_file "my_bucket", "some_file.txt"
      "Not implemented"
    )
