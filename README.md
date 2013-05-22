# `cloud_storage`

A library for connecting to [Google Cloud Storage](https://cloud.google.com/products/cloud-storage) through Lua.

## Tutorial

Communicating with Google Cloud Storage is done using what Google calls a
service account. You need to create a new service account and download the
private key that is generated with it. It's described in detail on [this
page][0] but here's a quicker tutorial focused on this library:

First head to the APIs console, <https://code.google.com/apis/console/>. Enable
cloud storage if you haven't done so already. You may also need to enter
billing information.

Now navigate to **Api Access** and click the big button "Create an OAuth 2.0
client ID".

![API Access](http://leafo.net/shotsnb/2013-05-21_23-58-04.png)


Follow the dialog, when you get to **Application type** make sure to select
**Service account**:

![x](http://leafo.net/shotsnb/2013-05-21_23-58-53.png)

Now you'll be given download access to the newly created private key, along
with the password which seems to be hard coded to `notasecret`.

![x](http://leafo.net/shotsnb/2013-05-22_00-00-05.png)

Download the private key, it's a `.p12` file. In order to use it we need to
convert it to a `.pem`. Run the following command (replacing `key.p12` and
`key.pem` with the input filename and desired output filename):

    ```bash
    openssl pkcs12 -in key.p12 -out key.pem -nodes -clcerts
    ```

We'll need one more piece of information, the service account email address.
It's of the form `111111111111@developer.gserviceaccount.com` where
111111111111 is your project id. You can find it on the page where you created
your service account:

![x](http://leafo.net/shotsnb/2013-05-22_00-07-18.png)

Now we're ready to write some code. Let's write a simple application that lists
the contents of a bucket. Remember, you must have access to the bucket. You can
create a new bucket from the APIs console if you don't already have one.

    ```lua
    local oauth = require "cloud_storage.oauth"

    -- replace with your service account email address
    o = oauth.OAuth("111111111111@developer.gserviceaccount.com", "path/to/key.pem")

    local google = require "cloud_storage.google"

    -- use your project id as the second argument, same number in service account email
    local storage = google.CloudStorage(o, "111111111111")

    local files = storage:get_bucket("my_bucket")
    ```

## Reference

### cloud_storage.oauth

Handles OAuth authenticated requests. You must create an OAuth object that will
be used with the cloud storage API.

    ```lua
    local oauth = require "cloud_storage.oauth"
    ```

#### `ouath_instance = oauth.OAuth(service_email, path_to_private key)`

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

<https://developers.google.com/storage/docs/reference-methods#getservice>

#### `storage:get_bucket(bucket)`

<https://developers.google.com/storage/docs/reference-methods#getbucket>

#### `storage:get_file(bucket, key)`

<https://developers.google.com/storage/docs/reference-methods#getobject>

#### `storage:delete_file(bucket, key)`

<https://developers.google.com/storage/docs/reference-methods#deleteobject>

#### `storage:head_file(bucket, key)`

<https://developers.google.com/storage/docs/reference-methods#headobject>

#### `storage:put_file(bucket, fname, opts={})`

Reads `fname` from disk and uploads it. The key of the file will be the name of
the file unless `opts.key` is provided. The mimetype of the file is guessed
based on the extension unless `opts.mimetype` is provided.

#### `storage:put_file_string(bucket, data, opts={})`

Uploads the string `data` to the bucket. `opts.key` must be provided, and will
be the key of the file in the bucket. Other options include:

 * `opts.mimetype`: sets `Content-type` header for the file, defaults to not being set
 * `opts.acl`: sets the `x-goog-acl` header for file, defaults to `public-read`
 * `opts.headers`: an optional array table of any additional headers to send

#### `storage:signed_url(bucket, key, expiration)`

Creates a temporarily URL for downloading an object regardless of it's ACL.
`expiration` is a unix timestamp in the future, like one generated from
`os.time()`.

  [0]: https://developers.google.com/storage/docs/accesscontrol
