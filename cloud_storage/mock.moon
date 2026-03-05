
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

class FileSystemStorageInterface
  new: (@root_path=".") =>

  mkdir_p: (path) =>
    current = if path\match "^/" then "/" else ""
    for part in path\gmatch "[^/]+"
      current ..= (if current == "" or current == "/" then "" else "/") .. part
      ok, err = lfs.mkdir current
      if not ok
        -- allow existing directories, fail on anything else
        mode = lfs.attributes current, "mode"
        assert mode == "directory", err
    true

  file_stat: (path) =>
    attr = lfs.attributes path
    return nil unless attr
    {
      size: attr.size
      last_modified: os.date "!%Y-%m-%dT%H:%M:%SZ", attr.modification
    }

  list_dirs: (path) =>
    out = {}
    for entry in lfs.dir path
      continue if entry == "." or entry == ".."
      full = "#{path}/#{entry}"
      if lfs.attributes(full, "mode") == "directory"
        table.insert out, entry

    table.sort out
    out

  list_files_recursive: (base_path) =>
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

  read_file: (path) =>
    f = io.open path
    return nil unless f
    data = f\read "*a"
    f\close!
    data

  write_file: (path, data) =>
    dir = path\match "(.+)/"
    @mkdir_p dir if dir

    f = assert io.open(path, "w")
    assert f\write data
    f\close!
    true

  delete_file: (path) =>
    return nil unless lfs.attributes path, "mode"
    os.remove path
    true

  bucket_path: (bucket) =>
    if @root_path == "." or @root_path == ""
      bucket
    else
      "#{@root_path}/#{bucket}"

  object_path: (bucket, key) =>
    "#{@bucket_path(bucket)}/#{key}"

  list_buckets: =>
    root_path = if @root_path == "" then "." else @root_path
    @mkdir_p root_path
    @list_dirs root_path

  list_bucket_files: (bucket) =>
    path = @bucket_path bucket
    @mkdir_p path
    files = @list_files_recursive path
    out = for file in *files
      full_path = "#{path}/#{file}"
      stat = @file_stat full_path
      {
        key: file
        size: stat and stat.size
        last_modified: stat and stat.last_modified
      }

    table.sort out, (a, b) -> a.key < b.key
    out

  read_object: (bucket, key) =>
    @read_file @object_path bucket, key

  write_object: (bucket, key, data) =>
    @write_file @object_path(bucket, key), data

  delete_object: (bucket, key) =>
    @delete_file @object_path(bucket, key)

  stat_object: (bucket, key) =>
    @file_stat @object_path bucket, key

class MockStorage
  new: (root_path=".", @url_prefix="") =>
    @fs = FileSystemStorageInterface root_path

  mock_headers: (headers, ctx) =>
    headers

  bucket: (bucket) =>
    validate_bucket bucket
    Bucket bucket, @

  _full_path: (bucket, key) =>
    validate_bucket bucket
    validate_key key
    @fs\object_path bucket, key

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
      prefix .. @fs\bucket_path bucket

  file_url: (bucket, key, opts) =>
    validate_bucket bucket
    validate_key key
    if opts and (opts.scheme or opts.subdomain)
      "#{@bucket_url bucket, opts}/#{key}"
    else
      prefix = if @url_prefix == "" then "" else @url_prefix .. "/"
      prefix .. @fs\object_path(bucket, key)

  get_service: =>
    out = for entry in *@fs\list_buckets!
      { name: entry }
    out

  get_bucket: (bucket) =>
    validate_bucket bucket
    @fs\list_bucket_files bucket

  put_file_string: (bucket, key, data, options={}) =>
    validate_bucket bucket
    assert not options.key, "key is not an option, but an argument"
    if type(data) == "table"
      error "put_file_string interface has changed: key is now the second argument"

    validate_key key
    assert type(data) == "string", "expected string for data"

    @fs\write_object bucket, key, data
    200

  put_file: (bucket, fname, options={}) =>
    validate_bucket bucket
    data = @fs\read_file fname
    error "Failed to read file: #{fname}" unless data

    key = options.key or fname
    if options.key
      options = {k,v for k,v in pairs options when k != "key"}

    @put_file_string bucket, key, data, options

  put_file_acl: (bucket, key, acl) =>
    validate_bucket bucket
    validate_key key
    error "Not implemented in MockStorage"

  copy_file: (source_bucket, source_key, dest_bucket, dest_key, options={}) =>
    validate_bucket source_bucket
    validate_key source_key
    validate_bucket dest_bucket
    validate_key dest_key

    data = @fs\read_object source_bucket, source_key
    return nil, "File not found: #{source_key}" unless data

    @put_file_string dest_bucket, dest_key, data

  compose: (bucket, key, source_keys, options={}) =>
    validate_bucket bucket
    validate_key key
    assert type(source_keys) == "table" and next(source_keys), "invalid source keys"

    chunks = {}
    for key_obj in *source_keys
      name = if type(key_obj) == "table" then key_obj.name else key_obj
      assert name, "missing source key name for compose"
      validate_key name

      data = @fs\read_object bucket, name
      return nil, "File not found: #{name}" unless data
      table.insert chunks, data

    @put_file_string bucket, key, table.concat chunks

  delete_file: (bucket, key) =>
    validate_bucket bucket
    validate_key key, "Invalid key for deletion (missing or empty string)"
    if @fs\delete_object bucket, key
      200
    else
      nil, "File not found: #{key}"

  get_file: (bucket, key) =>
    validate_bucket bucket
    validate_key key
    path = @fs\object_path bucket, key
    data = @fs\read_object bucket, key
    return nil, "File not found: #{key}" unless data

    stat = @fs\stat_object bucket, key
    size = (stat and stat.size) or #data
    last_modified = stat and stat.last_modified
    code = 200

    data, code, @mock_headers {
      "Content-length": size
      "Last-modified": last_modified
      "x-goog-generation": "mock"
    }, {
      method: "GET"
      :bucket
      :key
      :path
      :size
      :last_modified
      :code
      :data
    }

  head_file: (bucket, key) =>
    validate_bucket bucket
    validate_key key
    path = @fs\object_path bucket, key
    stat = @fs\stat_object bucket, key
    return nil, "File not found: #{key}" unless stat
    size = stat.size
    last_modified = stat.last_modified
    code = 200

    "", code, @mock_headers {
      "Content-length": size
      "Last-modified": last_modified
    }, {
      method: "HEAD"
      :bucket
      :key
      :path
      :size
      :last_modified
      :code
    }

{ :MockStorage, :validate_bucket, :validate_key, :FileSystemStorageInterface }
