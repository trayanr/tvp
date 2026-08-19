#include <stdio.h>
#include <ffi.h>

static int add(int a, int b)
{
    return a + b;
}

int main(void)
{
    ffi_cif cif;
    ffi_type *args[2];
    void *values[2];
    int a = 40;
    int b = 2;
    ffi_arg result;

    args[0] = &ffi_type_sint;
    args[1] = &ffi_type_sint;
    values[0] = &a;
    values[1] = &b;

    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 2, &ffi_type_sint, args) != FFI_OK)
        return 1;

    ffi_call(&cif, FFI_FN(add), &result, values);
    printf("%d\n", (int)result);
    return 0;
}
