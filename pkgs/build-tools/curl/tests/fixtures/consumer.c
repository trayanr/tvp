#include <curl/curl.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    const curl_version_info_data *info = curl_version_info(CURLVERSION_NOW);
    if (strcmp(info->version, LIBCURL_VERSION)) return 1;
    if (!(info->features & CURL_VERSION_SSL) || !(info->features & CURL_VERSION_HTTP2) || !(info->features & CURL_VERSION_ZSTD)) return 2;
    CURL *easy = curl_easy_init(); if (!easy) return 3;
    curl_easy_cleanup(easy); puts(info->version); return 0;
}
