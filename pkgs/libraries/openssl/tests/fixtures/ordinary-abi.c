#include <openssl/sha.h>
#include <openssl/ssl.h>
int main(void) {
    unsigned char digest[SHA_DIGEST_LENGTH];
    SSL_CTX *context;
    if (!SHA1((const unsigned char *)"tvp", 3, digest)) return 1;
    if (digest[0] != 0x52 || digest[1] != 0xd3) return 2;
#if OPENSSL_VERSION_NUMBER < 0x10100000L
    SSL_library_init();
    context = SSL_CTX_new(SSLv23_method());
#else
    context = SSL_CTX_new(TLS_method());
#endif
    if (!context) return 3;
    SSL_CTX_free(context);
    return 0;
}
