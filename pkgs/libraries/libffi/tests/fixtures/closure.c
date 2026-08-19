#include <stdio.h>
#include <ffi.h>

typedef int (*doubler)(int);

static void handler(ffi_cif *cif, void *ret, void **args, void *user)
{
    (void)cif;
    (void)user;
    *(ffi_arg *)ret = *(int *)args[0] * 2;
}

int main(void)
{
    ffi_cif cif;
    ffi_type *args[1];
    ffi_closure *closure;
    void *code;

    closure = ffi_closure_alloc(sizeof(ffi_closure), &code);
    if (!closure)
        return 1;

    args[0] = &ffi_type_sint;
    if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_sint, args) != FFI_OK)
        return 1;
    if (ffi_prep_closure_loc(closure, &cif, handler, NULL, code) != FFI_OK)
        return 1;

    printf("%d\n", ((doubler)code)(21));
    ffi_closure_free(closure);
    return 0;
}
