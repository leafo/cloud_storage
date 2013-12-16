
build::
	moonc cloud_storage/

local: build
	luarocks make --local cloud_storage-dev-1.rockspec

%.pem: %.p12
	openssl pkcs12 -in $< -out $@ -nodes -clcerts

