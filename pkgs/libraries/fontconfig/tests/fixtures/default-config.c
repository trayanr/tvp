#include <fontconfig/fontconfig.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int contains(FcStrList *list, const char *expected) {
    FcChar8 *s; int found = 0;
    if (!list) return 0;
    while ((s = FcStrListNext(list))) { puts((const char *)s); if (!strcmp((const char *)s, expected)) found = 1; }
    FcStrListDone(list); return found;
}
int main(int argc, char **argv) {
    if (argc != 2) return 1;
    char path[4096];
    FcConfig *config = FcInitLoadConfig();
    if (!config) return 2;
    snprintf(path, sizeof path, "%s/etc/fonts/conf.d", argv[1]);
    if (!contains(FcConfigGetConfigDirs(config), path)) return 3;
    snprintf(path, sizeof path, "%s/etc/fonts/fonts.conf", argv[1]);
    if (!contains(FcConfigGetConfigFiles(config), path)) return 4;
    FcChar8 *filename = FcConfigGetFilename(NULL, (const FcChar8 *)"fonts.conf");
    if (!filename || strcmp((const char *)filename, path)) return 5;
    FcStrFree(filename);
    snprintf(path, sizeof path, "%s/var/cache/fontconfig", argv[1]);
    if (!contains(FcConfigGetCacheDirs(config), path)) return 6;
    snprintf(path, sizeof path, "%s/fontconfig", getenv("XDG_CACHE_HOME"));
    if (!contains(FcConfigGetCacheDirs(config), path)) return 7;
    /* FcInitLoadConfig adds upstream's compiled template directory. */
    snprintf(path, sizeof path, "%s/share/fontconfig/conf.avail", argv[1]);
    FcConfigFileInfoIter iter;
    int found = 0; FcChar8 *name, *description; FcBool enabled;
    FcConfigFileInfoIterInit(config, &iter);
    do {
        if (!FcConfigFileInfoIterGet(config, &iter, &name, &description, &enabled)) break;
        if (!strncmp((const char *)name, path, strlen(path)) && !enabled) found = 1;
        FcStrFree(name); FcStrFree(description);
    } while (FcConfigFileInfoIterNext(config, &iter));
    if (!found) return 8;
    FcConfigDestroy(config); return 0;
}
