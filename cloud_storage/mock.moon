
import Bucket from require "cloud_storage.google"
lfs = require "lfs"

VALID_NAME_CHUNK = "^[%w%._%-]+$"
BUCKET_PATTERN = "^[a-z0-9][a-z0-9._-]*[a-z0-9]$"
BUCKET_MIN_LEN = 3
BUCKET_MAX_LEN = 63

validate_bucket = (bucket) ->
  assert type(bucket) == "string" and bucket != "", "Invalid bucket (missing or empty string)"
  assert #bucket >= BUCKET_MIN_LEN and #bucket <= BUCKET_MAX_LEN, "Invalid bucket (unsafe length)"
  assert bucket\match(BUCKET_PATTERN), "Invalid bucket (unsafe characters)"
  bucket

validate_key = (key, message="Invalid key (missing or empty string)") ->
  assert type(key) == "string" and key != "", message
  assert not key\match("^/"), "Invalid key (unsafe path structure)"
  assert not key\match("/$"), "Invalid key (unsafe path structure)"
  assert not key\match("//"), "Invalid key (unsafe path structure)"
  for chunk in key\gmatch "[^/]+"
    assert chunk != "." and chunk != ".." and chunk\match(VALID_NAME_CHUNK), "Invalid key (unsafe characters)"
  key

mkdir_p = (path) ->
  current = if path\match "^/" then "/" else ""
  for part in path\gmatch "[^/]+"
    current ..= (if current == "" or current == "/" then "" else "/") .. part
    ok, err = lfs.mkdir current
    if not ok
      -- allow existing directories, fail on anything else
      mode = lfs.attributes current, "mode"
      assert mode == "directory", err
  true

file_stat = (path) ->
  attr = lfs.attributes path
  return nil unless attr
  attr.size, os.date "!%Y-%m-%dT%H:%M:%SZ", attr.modification

list_files = (base_path) ->
  results = {}
  scan = (dir, prefix) ->
    for entry in lfs.dir dir
      continue if entry == "." or entry == ".."
      full = "#{dir}/#{entry}"
      mode = lfs.attributes full, "mode"
      if mode == "file"
        table.insert results, if prefix == "" then entry else "#{prefix}/#{entry}"
      elseif mode == "directory"
        scan full, (if prefix == "" then entry else "#{prefix}/#{entry}")
  scan base_path, ""
  results

class MockStorage
  new: (@dir_name=".", @url_prefix="") =>

  bucket: (bucket) =>
    validate_bucket bucket
    Bucket bucket, @

  _full_path: (bucket, key) =>
    validate_bucket bucket
    validate_key key
    dir = if @dir_name == "." then "" else @dir_name .. "/"
    "#{dir}#{bucket}/#{key}"

  bucket_url: (bucket, opts={}) =>
    validate_bucket bucket
    if opts.scheme or opts.subdomain
      scheme = opts.scheme or "https"
      base = if @url_prefix == "" then "localhost" else @url_prefix
      if opts.subdomain
        "#{scheme}://#{bucket}.#{base}"
      else
        "#{scheme}://#{base}/#{bucket}"
    else
      prefix = if @url_prefix == "" then "" else @url_prefix .. "/"
      prefix .. if @dir_name == "." then bucket else "#{@dir_name}/#{bucket}"

  file_url: (bucket, key, opts) =>
    validate_bucket bucket
    validate_key key
    if opts and (opts.scheme or opts.subdomain)
      "#{@bucket_url bucket, opts}/#{key}"
    else
      prefix = if @url_prefix == "" then "" else @url_prefix .. "/"
      prefix .. @_full_path bucket, key

  get_service: =>
    path = @dir_name
    mkdir_p path
    out = {}
    for entry in lfs.dir path
      continue if entry == "." or entry == ".."
      full = "#{path}/#{entry}"
      if lfs.attributes(full, "mode") == "directory"
        table.insert out, { name: entry }
    table.sort out, (a, b) -> a.name < b.name
    out

  get_bucket: (bucket) =>
    validate_bucket bucket
    path = "#{@dir_name}/#{bucket}"
    mkdir_p path
    files = list_files path
    out = for file in *files
      full_path = "#{path}/#{file}"
      size, last_modified = file_stat full_path
      { key: file, :size, :last_modified }
    table.sort out, (a, b) -> a.key < b.key
    out

  put_file_string: (bucket, key, data, options={}) =>
    validate_bucket bucket
    assert not options.key, "key is not an option, but an argument"
    if type(data) == "table"
      error "put_file_string interface has changed: key is now the second argument"

    validate_key key
    assert type(data) == "string", "expected string for data"

    path = @_full_path bucket, key
    dir = path\match "(.+)/"

    mkdir_p dir if dir
    f = assert io.open(path, "w")
    assert f\write data
    f\close!
    200

  put_file: (bucket, fname, options={}) =>
    validate_bucket bucket
    data = if f = io.open fname
      with f\read "*a"
        f\close!
    else
      error "Failed to read file: #{fname}"

    key = options.key or fname
    if options.key
      options = {k,v for k,v in pairs options when k != "key"}

    @put_file_string bucket, key, data, options

  delete_file: (bucket, key) =>
    validate_bucket bucket
    validate_key key, "Invalid key for deletion (missing or empty string)"
    path = @_full_path bucket, key
    if lfs.attributes path, "mode"
      os.remove path
      200
    else
      nil, "File not found: #{key}"

  get_file: (bucket, key) =>
    validate_bucket bucket
    validate_key key
    path = @_full_path bucket, key

    f = io.open path
    return nil, "File not found: #{key}" unless f
    data = f\read "*a"
    f\close!

    _, last_modified = file_stat path
    data, 200, {
      "Content-length": #data
      "Last-modified": last_modified
      "x-goog-generation": "mock"
    }

  head_file: (bucket, key) =>
    validate_bucket bucket
    validate_key key
    path = @_full_path bucket, key

    f = io.open path
    return nil, "File not found: #{key}" unless f
    f\close!

    size, last_modified = file_stat path
    "", 200, {
      "Content-length": size
      "Last-modified": last_modified
    }

{ :MockStorage, :validate_bucket, :validate_key }
