#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static void target_maps(int cxx, int unwind) {
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) abort();
    char line[4096]; int c=0, g=0, s=0;
    while (fgets(line, sizeof line, f)) {
        if (strstr(line, "libc.so.6")) {
            if (!strstr(line, TARGET_LIBC "/lib/libc.so.6")) abort();
            c=1;
        }
        if (strstr(line, "libgcc_s.so.1")) {
            if (!strstr(line, TARGET_GCC "/libgcc_s.so.1")) abort();
            g=1;
        }
        if (strstr(line, "libstdc++.so.")) {
            if (!strstr(line, TARGET_CXX "/lib/libstdc++.so.")) abort();
            s=1;
        }
        if (strstr(line, "/nix/store/")) fputs(line, stdout);
    }
    fclose(f);
    if (!c || (unwind && !g) || (cxx && !s)) abort();
}
