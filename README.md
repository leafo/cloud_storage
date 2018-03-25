# `cloud_storage`

[![Build Status](https://travis-ci.org/leafo/cloud_storage.svg?branch=master)](https://travis-ci.org/leafo/cloud_storage)

A library for connecting to [Google Cloud Storage](https://cloud.google.com/products/cloud-storage) through Lua.

## Tutorial

You can learn more about authenicating with Google Cloud Storage here:
<https://cloud.google.com/storage/docs/authentication>. Here's a quick guide on
getting started:

The easiest way use this library is to create a service account for your
project. You'll need to download a private key store it alongside your
configuration.

Go to the APIs console, <https://console.developers.google.com>. Enable
Cloud Storage if you haven't done so already. You may also need to enter
billing information.

Navigate to **Service accounts**, located on the sidebar. Find the **Create
service account** button and click it.

![Service accounts](http://leafo.net/shotsnb/2016-08-30_23-54-13.png)

Choose `P12` for the key type.

Now you'll be given download access to the newly created private key, along
with the password which is hard coded to `notasecret`.

![x](http://leafo.net/shotsnb/2016-08-30_23-56-12.png)

Download the private key, it's a `.p12` file. In order to use it we need to
convert it to a `.pem`. Run the following command (replacing `key.p12` and
`key.pem` with the input filename and desired output filename). Enter
`notasecret` for the password.

```bash
openssl pkcs12 -in key.p12 -out key.pem -nodes -clcerts
```

We'll need one more piece of information, the service account email address.
You'll find it labeled **Service account ID** on the service account list. It
might look something like `cloud-storage@my-project.iam.gserviceaccount.com`.

Now we're ready to write some code. Let's write a simple application that lists
the contents of a bucket. Remember, you must have access to the bucket. You can
create a new bucket from the console if you don't already have one.

```lua
local oauth = require "cloud_storage.oauth"

-- replace with your service account ID
o = oauth.OAuth("cloud-storage@my-project.iam.gserviceaccount.com", "path/to/key.pem")

local google = require "cloud_storage.google"

-- use your id as the second argument, everything before the @ in your service account ID
local storage = google.CloudStorage(o, "cloud-storage")

local files = storage:get_bucket("my_bucket")
```

## Reference

### Error handling for storage methods

Any methods that fail to execute will return `nil`, an error message, and an
object that represents the error. Successful responses will return a Lua table
containing the details of the operation.

### cloud_storage.oauth

Handles OAuth authenticated requests. You must create an OAuth object that will
be used with the cloud storage API.

```lua
local oauth = require "cloud_storage.oauth"
```

#### `ouath_instance = oauth.OAuth(service_email, path_to_private_key)`

Create a new OAuth object.

### cloud_storage.google

Communicates with the Google cloud storage API.

```lua
local google = require "cloud_storage.google"
```

#### `storage = oauth.CloudStorage(ouath_instance, project_id)`

```lua
local storage = google.CloudStorage(o, "111111111111")
```

#### `storage:get_service()`

<https://cloud.google.com/storage/docs/xml-api/get-service>

#### `storage:get_bucket(bucket)`

<https://cloud.google.com/storage/docs/xml-api/get-bucket>

#### `storage:get_file(bucket, key)`

<https://cloud.google.com/storage/docs/xml-api/get-object>

#### `storage:delete_file(bucket, key)`

<https://cloud.google.com/storage/docs/xml-api/delete-object>

#### `storage:head_file(bucket, key)`

<https://cloud.google.com/storage/docs/xml-api/head-object>

#### `storage:put_file(bucket, fname, opts={})`

Reads `fname` from disk and uploads it. The key of the file will be the name of
the file unless `opts.key` is provided. The mimetype of the file is guessed
based on the extension unless `opts.mimetype` is provided.

```lua
storage:put_file("my_bucket", "source.lua", { mimetype = "text/lua" })
```

#### `storage:put_file_string(bucket, data, opts={})`

Uploads the string `data` to the bucket. `opts.key` must be provided, and will
be the key of the file in the bucket. Other options include:

 * `opts.mimetype`: sets `Content-type` header for the file, defaults to not being set
 * `opts.acl`: sets the `x-goog-acl` header for file, defaults to `public-read`
 * `opts.headers`: an optional array table of any additional headers to send

```lua
storage:put_file_string("my_bucket", "hello world!", {
  key = "message.txt",
  mimetype = "text/plain",
  acl = "private"
})
```

#### `storage:signed_url(bucket, key, expiration)`

Creates a temporarily URL for downloading an object regardless of it's ACL.
`expiration` is a unix timestamp in the future, like one generated from
`os.time()`.

```lua
print(storage:signed_url("my_bucket", "message.txt", os.time() + 100))
```

  [0]: https://developers.google.com/storage/docs/accesscontrol
