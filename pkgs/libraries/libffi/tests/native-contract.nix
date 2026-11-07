{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [
    deps.python
    deps.binutils
    deps.patchelf
  ];
  libraries = [ package ];
  tests = {
    cxx-callback = {
      script = ''
        cat > callback.cc <<'CXX'
        #include <ffi.h>
        #include <cassert>
        static void sum(ffi_cif*, void *r, void **args, void *data) {
          *static_cast<int*>(r) = *static_cast<int*>(args[0]) + *static_cast<int*>(data);
        }
        int main() {
          ffi_cif cif; ffi_type *types[] = { &ffi_type_sint };
          assert(ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_sint, types) == FFI_OK);
          void *code; auto closure = static_cast<ffi_closure*>(ffi_closure_alloc(sizeof(ffi_closure), &code));
          assert(closure); int data = 2;
          assert(ffi_prep_closure_loc(closure, &cif, sum, &data, code) == FFI_OK);
          assert(reinterpret_cast<int(*)(int)>(code)(40) == 42);
          ffi_closure_free(closure);
        }
        CXX
        c++ callback.cc -lffi -o callback
        LD_TRACE_LOADED_OBJECTS=1 ./callback > loaded
        grep -F '${package}/lib/libffi.so.8' loaded >/dev/null
        ./callback
        test ! -e ${package}/lib/libffi.a
        printf callback-ok
      '';
      expected = "callback-ok";
    };
  };
}
