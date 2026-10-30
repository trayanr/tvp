# Native Linux wrappers. Build machinery is a bootstrap input; installed
# scripts refer only to the explicitly supplied runtime components.
{
  lib,
  platform,
  stdenv,
  gcc,
  binutils,
  libc,
  bash,
  perl,
  wrapGprofng ? false,
  # Bootstrap C libraries must not retain the parent's libstdc++ via an unused
  # RPATH. The final compiler runtime is owned and is available to C consumers.
  cRuntime ? true,
  # Final consumers such as autoPatchelf use this standard Nix interface.
  # Bootstrap stages do not need it and keep their existing derivations.
  supportMetadata ? false,
  # Construction callers retain their exact script paths and rendered install phases.
  protocolRevision ? 2,
  responseExpander ? null,
  coreutils ? null,
}:
assert platform.isNative;
assert platform.buildPlatform.config == stdenv.buildPlatform.config;
assert platform.hostPlatform.config == stdenv.hostPlatform.config;
assert platform.targetPlatform.config == stdenv.targetPlatform.config;
let
  # Render platform facts before handing scripts to the builder. Normalising
  # the source path preserves its hash when the rendered bytes are unchanged.
  scriptFor =
    file:
    builtins.path {
      name = baseNameOf file;
      path = builtins.toFile (baseNameOf file) (
        lib.replaceStrings [ "@dynamicLinker@" ] [ platform.dynamicLinker ] (builtins.readFile file)
      );
    };
  v3 = protocolRevision == 3;
  scripts = if v3 then ./v3 else ./.;
  responseSubstitutions = lib.optionalString v3 ''
    --subst-var-by responseExpander ${responseExpander} \
    --subst-var-by coreutils ${coreutils} \
  '';
  bintools = stdenv.mkDerivation {
    pname = "binutils-wrapper";
    inherit (binutils) version;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase =
      ''
        mkdir -p "$out/bin" "$out/nix-support"
        for linker in ld ld.bfd ld.gold; do
          if [ -x ${binutils}/bin/"$linker" ]; then
            substitute ${scriptFor (scripts + "/ld.sh")} "$out/bin/$linker" \
              --subst-var-by bash ${bash}/bin/bash \
              --subst-var-by binutils ${binutils} \
              --subst-var-by libc ${libc} \
              ${responseSubstitutions}--subst-var linker
            chmod +x "$out/bin/$linker"
          fi
        done
        for tool in ${binutils}/bin/*; do
          name="''${tool##*/}"
          test -e "$out/bin/$name" || ln -s "$tool" "$out/bin/$name"
        done
        substitute ${scripts + "/bintools-setup.sh"} "$out/nix-support/setup-hook" \
          --subst-var out
      ''
      + lib.optionalString supportMetadata ''
        printf '%s\n' ${libc}/${platform.dynamicLinker} > "$out/nix-support/dynamic-linker"
        printf '%s\n' ${libc} > "$out/nix-support/orig-libc"
      ''
      + lib.optionalString wrapGprofng ''
        # The raw upstream HTML program uses /usr/bin/env perl. Bind its named
        # interpreter here, including calls dispatched by the gprofng frontend.
        rm "$out/bin/gprofng" "$out/bin/gp-display-html"
        substitute ${./gprofng.sh} "$out/bin/gprofng" \
          --subst-var-by bash ${bash}/bin/bash \
        --subst-var-by binutils ${binutils}
        substitute ${./gp-display-html.sh} "$out/bin/gp-display-html" \
          --subst-var-by bash ${bash}/bin/bash \
          --subst-var-by perl ${perl} --subst-var-by binutils ${binutils}
        chmod +x "$out/bin/gprofng" "$out/bin/gp-display-html"
      '';
    passthru = {
      inherit binutils libc;
      bintools = binutils;
      targetPrefix = "";
      isGNU = true;
      dynamicLinker = "${libc}/${platform.dynamicLinker}";
    };
  };
  cc = stdenv.mkDerivation {
    pname = "gcc-wrapper";
    inherit (gcc) version;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    propagatedBuildInputs = [ bintools ];
    installPhase = ''
      mkdir -p "$out/bin" "$out/nix-support"
      for program in gcc g++ cpp; do
        substitute ${scriptFor (scripts + "/cc.sh")} "$out/bin/$program" \
          --subst-var-by bash ${bash}/bin/bash \
          --subst-var-by gcc ${gcc} \
          --subst-var-by bintools ${bintools} \
          --subst-var-by libc ${libc} \
          --subst-var-by cRuntime ${lib.boolToString cRuntime} \
          ${responseSubstitutions}--subst-var program
        chmod +x "$out/bin/$program"
      done
      ln -s gcc "$out/bin/cc"
      ln -s g++ "$out/bin/c++"
      for program in gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool; do
        ln -s ${gcc}/bin/"$program" "$out/bin/$program"
      done
      substitute ${scripts + "/cc-setup.sh"} "$out/nix-support/setup-hook" \
        --subst-var out --subst-var-by bintools ${bintools} \
        --subst-var-by libcBin ${libc.bin}
      printf '%s\n' ${gcc} > "$out/nix-support/orig-cc"
      printf '%s\n' ${libc} > "$out/nix-support/orig-libc"
    '';
    passthru = {
      inherit bintools libc;
      cc = gcc;
      targetPrefix = "";
      isGNU = true;
      isClang = false;
      defaultHardeningFlags = [
        "bindnow"
        "fortify"
        "format"
        "pic"
        "relro"
        "stackprotector"
        "strictoverflow"
      ];
    };
  };
in
{
  inherit cc bintools;
}
