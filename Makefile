
build::
	moonc cloud_storage/


%.pem: %.p12
	openssl pkcs12 -in $< -out $@ -nodes -clcerts

