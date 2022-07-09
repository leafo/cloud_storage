
mimetypes = require "mimetypes"
url = require "socket.url"

import insert, concat from table

math.randomseed os.time!

import type from require "moon"

class File
  new: (@fname) =>
  mime: => mimetypes.guess @fname
  content: =>
    if file = io.open @fname
      with file\read "*a"
        file\close!

rand_string = (len) ->
  shuffled = for i=1,len
    r = math.random 97, 122
    r-= 32 if math.random! >= 0.5
    r
  string.char unpack shuffled

-- multipart encodes params
-- returns encoded string,boundary
-- params is an a table of tuple tables:
-- params = {
--   {key1, value2},
--   {key2, value2},
-- }
encode = (params) ->
  chunks = for tuple in *params
    k,v = unpack tuple

    k = url.escape k
    buffer = { 'Content-Disposition: form-data; name="'.. k .. '"' }

    content = if type(v) == File
      -- how is this encoded?
      buffer[1] ..= '; filename="' .. v.fname .. '"'
      insert buffer, "Content-type: #{v\mime!}"
      v\content!
    else
      v

    insert buffer, ""
    insert buffer, content
    concat buffer, "\r\n"

  local boundary
  while true
    boundary = "Boundary#{rand_string 16}"
    for c in *chunks
      continue if c\find boundary
    do break

  inner = concat { "\r\n", "--", boundary, "\r\n" }

  (concat {
    "--", boundary, "\r\n"
    concat chunks, inner
   "\r\n", "--", boundary, "--", "\r\n"
  }), boundary

encode_tbl = (params) ->
  encode [{k,v} for k,v in pairs params]

{ :encode, :encode_tbl, :File }
