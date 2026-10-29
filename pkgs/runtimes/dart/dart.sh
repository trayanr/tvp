#!@bash@
export SSL_CERT_FILE="${SSL_CERT_FILE:-@certificates@}"
exec @dart@ "$@"
