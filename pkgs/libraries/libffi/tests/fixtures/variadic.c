#include <stdarg.h>
#include <stdio.h>
#include <ffi.h>

static int addv(int count, ...)
{
    va_list ap;
    int total = 0;
    int i;

    va_start(ap, count);
    for (i = 0; i < count; i++)
        total += va_arg(ap, int);
    va_end(ap);
    return total;
}

int main(void)
{
    ffi_cif cif;
    ffi_type *args[3];
    void *values[3];
    int count = 2;
    int a = 40;
    int b = 2;
    ffi_arg result;

    args[0] = &ffi_type_sint;
    args[1] = &ffi_type_sint;
    args[2] = &ffi_type_sint;
    values[0] = &count;
    values[1] = &a;
    values[2] = &b;

    if (ffi_prep_cif_var(&cif, FFI_DEFAULT_ABI, 1, 3, &ffi_type_sint, args) != FFI_OK)
        return 1;

    ffi_call(&cif, FFI_FN(addv), &result, values);
    printf("%d\n", (int)result);
    return 0;
}
