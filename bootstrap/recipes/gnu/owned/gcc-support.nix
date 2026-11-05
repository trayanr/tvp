# One GNU-native libiberty serves both generators and host; no musl archive.
{
  tvp,
  lib,
  base,
  bash,
  coreutils,
  profile,
  python,
  binutils,
  gnumake,
  tools,
  source,
  component,
  supportedCheck ? false,
}:
final:
let
  command =
    name: run:
    (final.base.environment final.environment)
    // {
      name = "${component}.${name}";
      cwd = "build";
      run = ''
        mkdir -p "$evidence"
        export SHELL=${bash}/bin/bash CONFIG_SHELL=${bash}/bin/bash
        export CC_FOR_BUILD="$CC" CXX_FOR_BUILD="$CXX"
        status=0
        ${bash}/bin/bash -euc ${lib.escapeShellArg run} > "$evidence/${name}.log" 2>&1 || status=$?
        printf '%s\n' "$status" > "$evidence/${name}.status"
        ${
          if
            builtins.elem name [
              "check"
              "supported-check"
            ]
          then
            ""
          else
            ''if (( status )); then cat "$evidence/${name}.log"; exit "$status"; fi''
        }
      '';
    };
in
{
  pname = "source-native-${component}";
  version = "16.2.0";
  src = source;
  inherit base bash coreutils;
  outputs = [
    "out"
    "evidence"
  ];
  environment.tools = [
    binutils
    gnumake
  ] ++ tools;
  plan =
    [
      {
        name = "${component}.prepare";
        run = ''
          cp -pr ${final.src} source
          chmod -R u+w source
          mkdir build
        '';
      }
      (command "configure" ''
        ${bash}/bin/bash ../source/${component}/configure --prefix="$out" \
          --build=x86_64-unknown-linux-gnu --host=x86_64-unknown-linux-gnu \
          ${lib.optionalString (component == "libiberty") "--enable-install-libiberty enable_host_pie=yes"}
        cp config.log "$evidence/"
      '')
      (command "build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash'')
      # Raw statuses are evidence, never an allowance or a conformance PASS.
      (command "check" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash check'')
    ]
    ++ lib.optional supportedCheck (
      command "supported-check" ''
        # Upstream HAVE_ELF/NATIVE unconditionally adds btest_lto, although this
        # compiler explicitly disables LTO. Remove only those generated variables.
        ${gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${bash}/bin/bash am__EXEEXT_6= am__append_10= check
      ''
    )
    ++ [
      (command "install" ''
        mkdir -p "$out/lib" "$out/include"
        ${
          if component == "libiberty" then
            ''
              cp pic/libiberty.a "$out/lib/libiberty.a"
              cp pic/libiberty.a "$out/lib/libiberty_pic.a"
              cp ../source/include/*.h "$out/include/"
            ''
          else
            ''
              cp .libs/libbacktrace.a libbacktrace.la "$out/lib/"
              cp backtrace-supported.h ../source/libbacktrace/backtrace.h "$out/include/"
              find . -name '*.log' -o -name '*.trs' | while read -r f; do
                mkdir -p "$evidence/raw/$(dirname "$f")"
                cp "$f" "$evidence/raw/$f"
              done
            ''
        }
      '')
    ];
}
