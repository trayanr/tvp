#include <stdio.h>
#include <unicode/ucol.h>

int main(void) {
    UErrorCode status = U_ZERO_ERROR;
    UCollator *collator = ucol_open("sv-SE", &status);
    if (U_FAILURE(status)) {
        return 1;
    }

#if U_ICU_VERSION_MAJOR_NUM < 50
    const UChar z[] = { 0x007a };
    const UChar a_umlaut[] = { 0x00e4 };
    UCollationResult ordering = ucol_strcoll(collator, z, 1, a_umlaut, 1);
#else
    UCollationResult ordering = ucol_strcollUTF8(collator, "z", 1, "\xc3\xa4", 2, &status);
#endif
    ucol_close(collator);
    if (U_FAILURE(status) || ordering != UCOL_LESS) {
        return 1;
    }
    puts("sv-SE");
    return 0;
}
