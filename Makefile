.PHONY: gen-cert
gen-cert:
	openssl req -x509 -nodes -newkey rsa:2048 -days 5000 -sha256 -keyout ./dnscrypt.pem -out ./dnscrypt.pem
