# Native CMake integration. Search declared inputs through CMake's own API.
tvpAddCmakePrefix() { addToSearchPath CMAKE_PREFIX_PATH "$1"; }
addEnvHooks "$targetOffset" tvpAddCmakePrefix
cmakeConfigurePhase() {
    runHook preConfigure
    local compilerLibc
    compilerLibc=$(${CC:-cc} -print-file-name=libc.so)
    case "$compilerLibc" in
        /nix/store/*/lib/libc.so)
            addToSearchPath CMAKE_PREFIX_PATH "$(dirname "$(dirname "$compilerLibc")")"
            ;;
    esac
    : "${cmakeBuildDir:=build}"
    mkdir -p "$cmakeBuildDir"
    cd "$cmakeBuildDir"
    local -a flagsArray=(
        "-DCMAKE_INSTALL_PREFIX=$prefix"
        "-DCMAKE_INSTALL_LIBDIR=lib"
        "-DCMAKE_BUILD_TYPE=${cmakeBuildType:-Release}"
        "-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF"
        "-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF"
    )
    if [ "${buildPhase-}" = ninjaBuildPhase ]; then flagsArray+=("-GNinja"); fi
    concatTo flagsArray cmakeFlags cmakeFlagsArray
    cmake "${cmakeDir:-..}" "${flagsArray[@]}"
    runHook postConfigure
}
if [ -z "${dontUseCmakeConfigure-}" ] && [ -z "${configurePhase-}" ]; then
    setOutputFlags=
    configurePhase=cmakeConfigurePhase
fi
