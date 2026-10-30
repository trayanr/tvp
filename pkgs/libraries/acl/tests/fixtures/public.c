#include <sys/acl.h>
#include <acl/libacl.h>
#include <assert.h>
#include <stdio.h>
int main(void) {
    mode_t mode = 0;
    acl_t a = acl_from_mode(0640), b = acl_from_text("u::rw-,g::r--,o::---");
    assert(a && b && acl_valid(a) == 0 && acl_cmp(a, b) == 0);
    assert(acl_equiv_mode(a, &mode) == 0 && (mode & 0777) == 0640);
    acl_entry_t e;
    acl_permset_t p;
    assert(acl_get_entry(a, ACL_FIRST_ENTRY, &e) == 1);
    assert(acl_get_permset(e, &p) == 0 && acl_get_perm(p, ACL_WRITE) == 1);
    assert(acl_delete_perm(p, ACL_WRITE) == 0 && acl_get_perm(p, ACL_WRITE) == 0);
    assert(acl_add_perm(p, ACL_EXECUTE) == 0 && acl_get_perm(p, ACL_EXECUTE) == 1);
    acl_t named = acl_from_text("u::rw-,u:12345:r--,g::r--,m::r--,o::---");
    assert(named && acl_valid(named) == 0 && acl_entries(named) == 5);
    assert(acl_equiv_mode(named, &mode) == 1);
    char *text = acl_to_text(named, NULL);
    acl_t copy = text ? acl_from_text(text) : NULL;
    assert(copy && acl_cmp(named, copy) == 0);
    acl_free(copy); acl_free(text); acl_free(named); acl_free(a); acl_free(b);
    puts("ok");
}
