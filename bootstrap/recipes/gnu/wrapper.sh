#!@bash@
for argument in "$@"; do
  case "$argument" in
    -m32|-mx32|-mmusl|-mbionic|-muclibc) printf '%s\n' 'unsupported GNU checkpoint ABI mode' >&2; exit 64;;
  esac
done
export PATH=@tools@
export SHELL=@bash@ CONFIG_SHELL=@bash@
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

exec @compiler@ "${extraRpath[@]}" "$@"
