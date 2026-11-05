#!@bash@

if [ 1 = "$#" ] && [ "x-v" = "x$1" ]; then
  # HACK! should not pass -Wl if there are no input files, otherwise libtool breaks
  exec -a "@origname@" @gcc@ -v
fi

# logic based on pkgs/build-support/bintools-wrapper/ld-wrapper.sh
# very hacky
extraRpath=()
# This standalone construction uses the fixed native store, even in env -i.
# An empty NIX_STORE must not turn this into a match for every absolute path.
store=/nix/store
prev=""
for param in "$@"; do
  case "$prev" in
    -L | -B)
      case "$param" in
        "$store"/*)
          extraRpath+=(-Xlinker -rpath -Xlinker "$param")
          ;;
        *)
          ;;
      esac
      ;;
    *)
      case "$param" in
        -L"$store"/* | -B"$store"/*)
          extraRpath+=(-Xlinker -rpath -Xlinker "${param:2}")
          ;;
        "$store"/*.so | "$store"/*.so.*)
          extraRpath+=(-Xlinker -rpath -Xlinker "${param%/*}")
          ;;
        *)
          ;;
      esac
      ;;
  esac
  prev="$param"
done

# Order of -B is very particular. musl detection in gnulib requires that
# libc/.. comes before libgcc, otherwise libc is assumed to be glibc.
exec -a "@origname@" @gcc@ -Wl,-dynamic-linker=@dynlinker@ \
  @extraflags@ \
  "${extraRpath[@]}" \
  -Wl,-rpath,@libc@ \
  -B@libc@/.. \
  -B@libgcc@ \
  -B@libc@ \
  -B@origdir@ \
  -B@binutils@ \
  -isystem @gccinc@ \
  "$@"
