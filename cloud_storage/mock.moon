
import Bucket from require "cloud_storage.google"

shell_escape = (str) ->
  str\gsub "'", "''"

execute = (cmd) ->
  -- print "RUN: #{cmd}"
  proc = io.popen cmd
  out = proc\read "*a"
  proc\close!
  out\match "^(.-)%s*$"

class MockStorage
  new: (@dir_name=".", @url_prefix="") =>

  bucket: (bucket) => Bucket bucket, @

  _full_path: (bucket, key) =>
    dir = if @dir_name == "." then "" else @dir_name .. "/"
    "#{dir}#{bucket}/#{key}"

  file_url: (bucket, key) =>
    prefix = if @url_prefix == "" then "" else @url_prefix .. "/"
    prefix .. @_full_path bucket, key

  get_service: => error "Not implemented"

  get_bucket: (bucket) =>
    path = "#{@dir_name}/#{bucket}"
    execute "mkdir -p '#{shell_escape path}'"
    escaped_path = "$(echo '#{shell_escape path}' | sed -e 's/[\\/&]/\\\\&/g')"
    cmd = 'find "'..shell_escape(path)..'" -type f | sed -e "s/^'..escaped_path..'//"'
    files = execute cmd
    return for file in files\gmatch "[^\n]+"
      { key: file\match "/?(.*)" }

  put_file_string: (bucket, key, data, options={}) =>
    assert not options.key, "key is not an option, but an argument"
    if type(data) == "table"
      error "put_file_string interface has changed: key is now the second argument"

    assert key, "missing key"
    assert type(data) == "string", "expected string for data"

    path = @_full_path bucket, key
    dir = execute "dirname '#{shell_escape path}'"

    execute "mkdir -p '#{shell_escape dir}'"
    with io.open path, "w"
      \write data
      \close!
    200

  put_file: (bucket, fname, options={}) =>
    data = if f = io.open fname
      with f\read "*a"
        f\close!
    else
      error "Failed to read file: #{fname}"

    @put_file_string bucket, data, options

  delete_file: (bucket, key) =>
    path = @_full_path bucket, key
    os.execute "[ -a '#{shell_escape path}' ] && rm '#{shell_escape path}'"
    200

  get_file: (bucket, key) => error "not implemented"
  head_file: (bucket, key) => error "Not implemented"


if ... == "test"
  moon = require "moon"
  s = MockStorage("test_storage", "static")

  print s\_full_path "dad_bucket", "eat/my/sucks"
  print MockStorage!\_full_path "nobucket", "hello.world"

  print!

  b = s\bucket "my_bucket"

  b\put_file_string "this is a file", key: "some_file.txt"
  b\put_file_string "yeah", key: "something/with/path.cpp"
  b\put_file "hi.lua", key: "cool/thing.lua"

  moon.p b\list!

  b\delete_file "some_file.txt"
  b\delete_file "cool/does_not_exist.txt"

  moon.p b\list!

  print b\file_url "cool/does_not_exist.txt"

{ :MockStorage }
