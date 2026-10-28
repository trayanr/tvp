tvpAddMesonPrefix() {
    addToSearchPath PKG_CONFIG_PATH "$1/lib/pkgconfig"
    addToSearchPath PKG_CONFIG_PATH "$1/share/pkgconfig"
    addToSearchPath CMAKE_PREFIX_PATH "$1"
}
addEnvHooks "$targetOffset" tvpAddMesonPrefix
mesonConfigurePhase() {
    runHook preConfigure
    : "${mesonBuildDir:=build}"
    local -a flagsArray=("--prefix=$prefix" --libdir=lib --buildtype=release --wrap-mode=nodownload -Dauto_features=enabled)
    concatTo flagsArray mesonFlags mesonFlagsArray
    meson setup "$mesonBuildDir" "${mesonDir:-.}" "${flagsArray[@]}"
    cd "$mesonBuildDir"
    runHook postConfigure
}
mesonBuildPhase() {
    runHook preBuild
    local cores=1
    if [ -n "${enableParallelBuilding-1}" ]; then cores="$NIX_BUILD_CORES"; fi
    local -a flagsArray=(-j "$cores")
    concatTo flagsArray mesonBuildFlags mesonBuildFlagsArray
    meson compile "${flagsArray[@]}"
    runHook postBuild
}
mesonCheckPhase() {
    runHook preCheck
    local -a flagsArray=(--print-errorlogs)
    concatTo flagsArray mesonCheckFlags mesonCheckFlagsArray
    meson test "${flagsArray[@]}"
    runHook postCheck
}
mesonInstallPhase() {
    runHook preInstall
    local -a flagsArray=(--no-rebuild)
    concatTo flagsArray mesonInstallFlags mesonInstallFlagsArray
    meson install "${flagsArray[@]}"
    runHook postInstall
}
if [ -z "${dontUseMesonConfigure-}" ] && [ -z "${configurePhase-}" ]; then setOutputFlags=; configurePhase=mesonConfigurePhase; fi
if [ -z "${dontUseMesonBuild-}" ] && [ -z "${buildPhase-}" ]; then buildPhase=mesonBuildPhase; fi
if [ -z "${dontUseMesonCheck-}" ] && [ -z "${checkPhase-}" ]; then checkPhase=mesonCheckPhase; fi
if [ -z "${dontUseMesonInstall-}" ] && [ -z "${installPhase-}" ]; then installPhase=mesonInstallPhase; fi
