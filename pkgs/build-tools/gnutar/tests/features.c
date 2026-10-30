#include <sys/types.h>
#include <sys/acl.h>
#include <sys/xattr.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
/* 77 is reserved for an explicitly unsupported filesystem/kernel capability.
   Permission, IO and all other unexpected errors fail the test. */
static void error(const char *what) {
  int e = errno;
  fprintf(stderr, "%s: errno=%d: %s\n", what, e, strerror(e));
  exit(e == EOPNOTSUPP || e == ENOSYS ? 77 : 1);
}
int main(int argc, char **argv) {
  if (argc != 4) return 2;
  int set = strcmp(argv[1], "set") == 0;
  if (strcmp(argv[2], "xattr") == 0) {
    const char value[] = "preserved";
    if (set) {
      if (setxattr(argv[3], "user.tvp", value, sizeof value, 0)) error("setxattr");
    } else {
      char buf[100];
      ssize_t n = getxattr(argv[3], "user.tvp", buf, sizeof buf);
      if (n < 0) error("getxattr");
      if (n != sizeof value || memcmp(buf, value, sizeof value)) return 1;
    }
  } else {
    char text[200];
    snprintf(text, sizeof text, "user::rw-,user:%u:r--,group::---,mask::r--,other::---", (unsigned)getuid() + 1);
    acl_t want = acl_from_text(text);
    if (!want) error("acl_from_text");
    if (set) {
      if (acl_set_file(argv[3], ACL_TYPE_ACCESS, want)) error("acl_set_file");
    } else {
      acl_t got = acl_get_file(argv[3], ACL_TYPE_ACCESS);
      if (!got) error("acl_get_file");
      /* Canonical text includes the same entries, permissions and mask. */
      char *a = acl_to_text(want, NULL), *b = acl_to_text(got, NULL);
      if (!a || !b) error("acl_to_text");
      int diff = strcmp(a, b);
      if (diff) fprintf(stderr, "ACL mismatch: %s / %s\n", a, b);
      acl_free(a); acl_free(b); acl_free(got);
      if (diff) return 1;
    }
    acl_free(want);
  }
  return 0;
}
