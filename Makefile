
build::
	moonc cloud_storage/

local: build
	luarocks --lua-version=5.1 make --local cloud_storage-dev-1.rockspec

%.pem: %.p12
	openssl pkcs12 -in $< -out $@ -nodes -clcerts


%.rsa.pem: %.p12
	openssl pkcs12 -nodes -nocerts -in $< | openssl rsa -out $@ 

