/* stdio first: 0.9.8's sha.h uses size_t without including stddef itself. */
#include <stdio.h>
#include <openssl/sha.h>

int main(void) {
  unsigned char digest[SHA256_DIGEST_LENGTH];
  const char *input = "tvp";
  int i;

  SHA256((const unsigned char *)input, 3, digest);
  for (i = 0; i < 8; i++) {
    printf("%02x", digest[i]);
  }
  return 0;
}
