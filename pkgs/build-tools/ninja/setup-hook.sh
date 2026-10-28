# Native build phases for a declared Ninja input.
tvpNinjaFlags() {
    local cores=1
    if [ -n "$1" ]; then cores="$NIX_BUILD_CORES"; fi
    flagsArray=("-j$cores")
    concatTo flagsArray ninjaFlags ninjaFlagsArray
}
ninjaBuildPhase() {
    runHook preBuild
    local -a flagsArray
    tvpNinjaFlags "${enableParallelBuilding-1}"
    ninja "${flagsArray[@]}"
    runHook postBuild
}
ninjaCheckPhase() {
    runHook preCheck
    local -a flagsArray
    tvpNinjaFlags "${enableParallelChecking-1}"
    concatTo flagsArray checkFlags checkFlagsArray
    ninja "${flagsArray[@]}" "${checkTarget:-test}"
    runHook postCheck
}
ninjaInstallPhase() {
    runHook preInstall
    local -a flagsArray
    tvpNinjaFlags "${enableParallelInstalling-1}"
    concatTo flagsArray installFlags installFlagsArray
    : "${installTargets:=install}"
    concatTo flagsArray installTargets
    ninja "${flagsArray[@]}"
    runHook postInstall
}
if [ -z "${dontUseNinjaBuild-}" ] && [ -z "${buildPhase-}" ]; then buildPhase=ninjaBuildPhase; fi
if [ -z "${dontUseNinjaCheck-}" ] && [ -z "${checkPhase-}" ]; then checkPhase=ninjaCheckPhase; fi
if [ -z "${dontUseNinjaInstall-}" ] && [ -z "${installPhase-}" ]; then installPhase=ninjaInstallPhase; fi
