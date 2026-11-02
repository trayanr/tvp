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
      xz,
    }:
    steps.namespace "source" [
      {
        name = "unpack";
        tools = [
          tar
          xz
        ];
        run = ''
          mkdir source
          tar -xJf ${src} --strip-components=1 -C source
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
        run = ''./configure --prefix="$out" ${lib.escapeShellArgs configureFlags}'';
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
