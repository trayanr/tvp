#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <openssl/ssl.h>
#include <openssl/rsa.h>
#include <openssl/provider.h>
#include <openssl/err.h>
int main(void) {
 OSSL_PROVIDER *d=OSSL_PROVIDER_load(NULL,"default"), *l=OSSL_PROVIDER_load(NULL,"legacy");
 assert(d && l); assert(OSSL_PROVIDER_available(NULL,"default"));
 EVP_PKEY *key=EVP_RSA_gen(2048); assert(key);
 X509 *cert=X509_new(); assert(cert); assert(X509_set_version(cert,2));
 ASN1_INTEGER_set(X509_get_serialNumber(cert),1);
 X509_gmtime_adj(X509_getm_notBefore(cert),-60); X509_gmtime_adj(X509_getm_notAfter(cert),3600);
 assert(X509_set_pubkey(cert,key)); X509_NAME *name=X509_get_subject_name(cert);
 assert(X509_NAME_add_entry_by_txt(name,"CN",MBSTRING_ASC,(const unsigned char*)"localhost",-1,-1,0));
 assert(X509_set_issuer_name(cert,name)); assert(X509_sign(cert,key,EVP_sha256()));
 SSL_CTX *server=SSL_CTX_new(TLS_server_method()), *client=SSL_CTX_new(TLS_client_method());
 assert(server && client); assert(SSL_CTX_use_certificate(server,cert)); assert(SSL_CTX_use_PrivateKey(server,key));
 SSL *s=SSL_new(server), *c=SSL_new(client); BIO *a,*b; assert(BIO_new_bio_pair(&a,0,&b,0));
 SSL_set_bio(c,a,a); SSL_set_bio(s,b,b); SSL_set_connect_state(c); SSL_set_accept_state(s);
 for(int i=0;i<1000 && !(SSL_is_init_finished(c)&&SSL_is_init_finished(s));i++) {
   int r=SSL_do_handshake(c); if(r!=1) { int e=SSL_get_error(c,r); assert(e==SSL_ERROR_WANT_READ||e==SSL_ERROR_WANT_WRITE); }
   r=SSL_do_handshake(s); if(r!=1) { int e=SSL_get_error(s,r); assert(e==SSL_ERROR_WANT_READ||e==SSL_ERROR_WANT_WRITE); }
 }
 assert(SSL_is_init_finished(c)&&SSL_is_init_finished(s));
 const char msg[]="local TLS memory BIO"; char result[64];
 assert(SSL_write(c,msg,sizeof msg)==sizeof msg); assert(SSL_read(s,result,sizeof result)==sizeof msg); assert(!memcmp(msg,result,sizeof msg));
 printf("TLS handshake and application data PASS: %s\n",SSL_get_version(c));
 FILE *f=fopen("/proc/self/maps","r"); assert(f); char line[4096];
 while(fgets(line,sizeof line,f)) if(strstr(line,"/nix/store/")) fputs(line,stdout); fclose(f);
 SSL_free(c);SSL_free(s);SSL_CTX_free(client);SSL_CTX_free(server);X509_free(cert);EVP_PKEY_free(key);
 OSSL_PROVIDER_unload(l);OSSL_PROVIDER_unload(d);return 0;
}
