#include <oniguruma.h>
#include <stdio.h>

int main(void)
{
    static const OnigUChar pattern[] = "猫[0-9]+";
    static const OnigUChar text[] = "x猫42y";
    const OnigUChar *end = text + sizeof(text) - 1;
    OnigEncoding encodings[] = {ONIG_ENCODING_UTF8};
    OnigRegex regex;

    if (onig_initialize(encodings, 1) != ONIG_NORMAL)
        return 1;
    if (onig_new(&regex, pattern, pattern + sizeof(pattern) - 1,
                 ONIG_OPTION_NONE, ONIG_ENCODING_UTF8, ONIG_SYNTAX_DEFAULT,
                 NULL) != ONIG_NORMAL)
        return 1;

    OnigRegion *region = onig_region_new();
    if (region == NULL)
        return 1;
    int matched = onig_search(regex, text, end, text, end, region,
                              ONIG_OPTION_NONE) == 1 &&
                  region->beg[0] == 1 && region->end[0] == 6;
    onig_region_free(region, 1);
    onig_free(regex);
    onig_end();
    if (!matched)
        return 1;

    puts("utf8-match");
    return 0;
}
