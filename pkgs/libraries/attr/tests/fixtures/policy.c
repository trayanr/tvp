#include <attr/libattr.h>
#include <stdio.h>
int main(void) {
    if (attr_copy_action("user.tvp", NULL) != 0) return 1;
    if (attr_copy_action("system.posix_acl_access", NULL) != ATTR_ACTION_PERMISSIONS) return 2;
    puts("ok");
    return 0;
}
