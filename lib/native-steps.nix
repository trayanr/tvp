# Internal native helpers return ordinary editable records. Setup still supplies
# compiler/search hooks; these explicit calls retain required legacy effects.
{ lib }:
let
  steps = import ./build-steps.nix;
in
{
  unpack =
    {
      src,
      tar,
      xz ? null,
      gzip ? null,
      compression ? "xz",
    }:
    steps.namespace "source" [
      {
        name = "unpack";
        tools = [
          tar
          (
            if compression == "xz" then
              if xz == null then throw "Native xz source requires an xz tool" else xz
            else if compression == "gzip" then
              if gzip == null then throw "Native gzip source requires a gzip tool" else gzip
            else
              throw "Unsupported native source compression: ${compression}"
          )
        ];
        run = ''
          mkdir source
          tar -x${if compression == "xz" then "J" else "z"}f ${src} --strip-components=1 -C source
          chmod -R u+w source
          updateSourceDateEpoch source
          printf '%s\n' "$SOURCE_DATE_EPOCH" > source-date-epoch
        '';
      }
    ];
  autotools =
    {
      name,
      make,
      libraries,
      configureFlags ? [ ],
      doCheck ? true,
    }:
    steps.namespace name [
      {
        name = "configure";
        tools = [ make ];
        inherit libraries;
        cwd = "source";
        run = ''
          # Retain the selected base's libtool/shell corrections explicitly.
          set +u
          export lt_cv_deplibs_check_method=pass_all
          while IFS= read -r -d $'\0' script; do fixLibtool "$script"; done < <(find . -name ltmain.sh -print0)
          patchShebangs --build ./configure
          touch -r ./configure "$TMPDIR/configure-mtime"
          sed -i 's_/usr/bin/file_file_g' ./configure
          touch -r "$TMPDIR/configure-mtime" ./configure
          set -u
          ./configure --prefix="$out" ${lib.escapeShellArgs configureFlags}
        '';
      }
      {
        name = "build";
        tools = [ make ];
        inherit libraries;
        cwd = "source";
        run = ''make -j"$NIX_BUILD_CORES"'';
      }
      {
        name = "check";
        enabled = doCheck;
        tools = [ make ];
        inherit libraries;
        cwd = "source";
        run = ''make -j"$NIX_BUILD_CORES" check'';
      }
      {
        name = "install";
        tools = [ make ];
        inherit libraries;
        cwd = "source";
        run = ''make -j"$NIX_BUILD_CORES" install'';
      }
    ];
  # Direct native Make. Keep upstream compiler/flag defaults and recursive MAKE;
  # absolute invocation ensures a tool override also controls recursive targets.
  make =
    {
      name,
      make,
      tools ? [ ],
      libraries ? [ ],
      env ? { },
      cwd ? "source",
      makeFlags ? [ ],
      buildTargets ? [ ],
      checkTargets ? [ "check" ],
      installTargets ? [ "install" ],
      doCheck ? true,
    }:
    let
      record = phase: targets: {
        name = phase;
        tools = [ make ] ++ tools;
        inherit libraries env cwd;
        run = ''${make}/bin/make -j"$NIX_BUILD_CORES" ${lib.escapeShellArgs (makeFlags ++ targets)}'';
      };
    in
    steps.namespace name [
      (record "build" buildTargets)
      ((record "check" checkTargets) // { enabled = doCheck; })
      (record "install" installTargets)
    ];
  # Modern native Meson only. Preparation and finalization remain separate.
  meson =
    {
      name,
      meson,
      ninja,
      pkg-config,
      tools ? [ ],
      libraries ? [ ],
      env ? { },
      mesonFlags ? [ ],
      doCheck ? true,
    }:
    let
      inputs = [
        meson
        ninja
        pkg-config
      ] ++ tools;
      # The selected Meson launcher embeds defaults: PATH alone cannot override
      # these programs. Export the supplied arguments in every fresh shell.
      environment = env // {
        NINJA = "${ninja}/bin/ninja";
        PKG_CONFIG = "${pkg-config}/bin/pkg-config";
      };
    in
    steps.namespace name [
      {
        name = "configure";
        tools = inputs;
        inherit libraries;
        env = environment;
        cwd = "source";
        run = ''
          meson setup build . --prefix="$out" --libdir=lib --buildtype=release --wrap-mode=nodownload -Dauto_features=enabled ${lib.escapeShellArgs mesonFlags}
        '';
      }
      {
        name = "build";
        tools = inputs;
        inherit libraries;
        env = environment;
        cwd = "source/build";
        run = ''meson compile -j "$NIX_BUILD_CORES"'';
      }
      {
        name = "check";
        enabled = doCheck;
        tools = inputs;
        inherit libraries;
        env = environment;
        cwd = "source/build";
        run = "meson test --print-errorlogs";
      }
      {
        name = "install";
        tools = inputs;
        inherit libraries;
        env = environment;
        cwd = "source/build";
        run = "meson install --no-rebuild";
      }
    ];
  finalize =
    {
      propagatedLibraries ? [ ],
    }:
    steps.namespace "output" [
      {
        name = "fixup";
        libraries = propagatedLibraries;
        run = ''
          outputs=out
          propagatedBuildInputs=(${
            lib.concatMapStringsSep " " (p: lib.escapeShellArg (toString p)) propagatedLibraries
          })
          dontStrip= dontShrinkRpaths= noAuditTmpdir=
          stripDebugList='lib lib32 lib64 libexec bin sbin'
          stripDebugFlags='-S -p'
          set +u
          fixupPhase
          # The retained hook audits this step's TMPDIR. Also audit the shared
          # build root so paths from source/build or earlier steps cannot escape.
          ( TMPDIR="$NIX_BUILD_TOP"; auditTmpdir "$out" )
          set -u
        '';
      }
    ];
}
