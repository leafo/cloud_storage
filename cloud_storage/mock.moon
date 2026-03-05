
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

    key = options.key or fname
    if options.key
      options = {k,v for k,v in pairs options when k != "key"}

    @put_file_string bucket, key, data, options

  delete_file: (bucket, key) =>
    path = @_full_path bucket, key
    os.execute "[ -a '#{shell_escape path}' ] && rm '#{shell_escape path}'"
    200

  get_file: (bucket, key) => error "not implemented"
  head_file: (bucket, key) => error "Not implemented"

{ :MockStorage }
