
%.pem: %.p12
	openssl pkcs12 -in $< -out $@ -nodes -clcerts

