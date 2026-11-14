#include <curl/curl.h>
#include <stdio.h>
int main(void) {
    CURL *easy = curl_easy_init();
    char *file = NULL, *directory = NULL;
    if (!easy) return 1;
    if (curl_easy_getinfo(easy, CURLINFO_CAINFO, &file) != CURLE_OK || !file) return 2;
    if (curl_easy_getinfo(easy, CURLINFO_CAPATH, &directory) != CURLE_OK || directory) return 3;
    puts(file);
    curl_easy_cleanup(easy);
    return 0;
}
