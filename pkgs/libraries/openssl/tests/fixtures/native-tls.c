#include <openssl/ssl.h>
#include <assert.h>
#include <string.h>
static void tls(int version) {
    SSL_CTX *server=SSL_CTX_new(TLS_server_method()), *client=SSL_CTX_new(TLS_client_method());
    assert(server && client);
    assert(SSL_CTX_set_min_proto_version(server,version));
    assert(SSL_CTX_set_max_proto_version(server,version));
    assert(SSL_CTX_set_min_proto_version(client,version));
    assert(SSL_CTX_set_max_proto_version(client,version));
    assert(SSL_CTX_use_certificate_file(server,"cert.pem",SSL_FILETYPE_PEM)==1);
    assert(SSL_CTX_use_PrivateKey_file(server,"key.pem",SSL_FILETYPE_PEM)==1);
    assert(SSL_CTX_load_verify_locations(client,"cert.pem",NULL)==1);
    SSL_CTX_set_verify(client,SSL_VERIFY_PEER,NULL);
    SSL *s=SSL_new(server),*c=SSL_new(client);
    assert(s && c); assert(SSL_set1_host(c,"localhost"));
    BIO *sb,*cb; assert(BIO_new_bio_pair(&sb,0,&cb,0)==1);
    SSL_set_bio(s,sb,sb); SSL_set_bio(c,cb,cb);
    SSL_set_accept_state(s); SSL_set_connect_state(c);
    for(int i=0;i<100 && (!SSL_is_init_finished(s)||!SSL_is_init_finished(c));++i) {
        int r=SSL_do_handshake(s); if(r!=1) {int e=SSL_get_error(s,r); assert(e==SSL_ERROR_WANT_READ||e==SSL_ERROR_WANT_WRITE);}
        r=SSL_do_handshake(c); if(r!=1) {int e=SSL_get_error(c,r); assert(e==SSL_ERROR_WANT_READ||e==SSL_ERROR_WANT_WRITE);}
    }
    assert(SSL_is_init_finished(s)&&SSL_is_init_finished(c));
    assert(SSL_get_verify_result(c)==X509_V_OK);
    assert(SSL_version(c)==version);
    assert(SSL_write(c,"tvp",3)==3); char b[4]={0}; assert(SSL_read(s,b,3)==3); assert(!strcmp(b,"tvp"));
    SSL_free(c); SSL_free(s); SSL_CTX_free(client); SSL_CTX_free(server);
}
int main(void) {tls(TLS1_2_VERSION); tls(TLS1_3_VERSION);}
