#include <sys/acl.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    acl_t acl = acl_from_text("user::rw-,user:12345:r--,group::r--,mask::r--,other::---");
    if (!acl || acl_valid(acl)) return 1;
    char *text = acl_to_text(acl, NULL);
    if (!text || !strstr(text, "user:12345:r--")) return 2;
    acl_t copy = acl_from_text(text);
    if (!copy || acl_valid(copy)) return 3;
    acl_free(copy); acl_free(text); acl_free(acl);
    puts("ok");
    return 0;
}
