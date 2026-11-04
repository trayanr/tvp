# 2.6.0 only. Compiled locale/configuration paths retain the configured prefix.
{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnutar,
  gzip,
  python,
  perl,
  binutils,
  patchelf,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [
    "bin"
    "lib/libattr.so.1.1.2600"
  ];
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "attr";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [ gnumake ];
    libraries = [ ];
  };
  runtime.libraries = [ ];
  plan = steps.sequence [
    (steps.unpack {
      inherit src gzip;
      tar = gnutar;
      compression = "gzip";
    })
    (steps.prepareAutotools {
      name = "attr.prepare";
      inherit bash python;
      base = final.base;
    })
    (steps.shebangs {
      name = "attr.test-perl";
      inherit python;
      paths = [
        "test/run"
        "test/sort-getfattr-output"
      ];
      names = [ "perl" ];
      interpreter = "${perl}/bin/perl";
    })
    (command "attr.configure" ''
      export CONFIG_SHELL=${bash}/bin/bash
      export lt_cv_deplibs_check_method=pass_all
      ./configure --prefix="$out" --enable-shared --enable-static
    '')
    (command "attr.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (
      (command "attr.check" ''
        status=0
              ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check || status=$?
              cat test-suite.log
              exit "$status"'')
      // {
        enabled = doCheck;
        tools = environment.tools ++ [ perl ];
      }
    )
    (command "attr.install" ''
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" install
      mkdir -p "$out/nix-support"
      cp "$TVP_SOURCE_ROOT/source-date-epoch" "$out/nix-support/source-date-epoch"
    '')
    {
      name = "output.manuals";
      tools = [ gzip ];
      run = ''
        while IFS= read -r -d $'\0' manual; do
          ${gzip}/bin/gzip -n -9 "$manual"
        done < <(find "$out/share/man" -type f ! -name '*.gz' -print0)
        while IFS= read -r -d "" manual; do
          target=$(readlink "$manual")
          rm "$manual"
          ln -s "$target.gz" "$manual.gz"
        done < <(find "$out/share/man" -type l ! -name '*.gz' -print0)
      '';
    }
    (outputs.strip {
      inherit python binutils;
      paths = elfPaths;
    })
    (outputs.stripArchives {
      inherit python binutils;
      paths = [ "lib/libattr.a" ];
    })
    (outputs.libtool {
      inherit python;
      paths = [ "lib/libattr.la" ];
    })
    (outputs.rpaths {
      inherit python binutils patchelf;
      base = final.base;
      libraries = final.runtime.libraries;
      paths = elfPaths;
    })
    (outputs.development {
      inherit python;
      libraries = [ ];
    })
    (outputs.checkSymlinks {
      inherit python;
      paths = [
        "lib/libattr.so"
        "lib/libattr.so.1"
      ];
    })
    (outputs.checkPaths {
      inherit python binutils patchelf;
      paths = elfPaths;
    })
  ];
  tvp.features = {
    shared = true;
    static = true;
  };
  meta = {
    description = "Extended attribute utilities and library";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}
