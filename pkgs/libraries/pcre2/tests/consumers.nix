{
  pkgs,
  package,
}:
let
  lib = pkgs.lib;
  since = v: lib.versionAtLeast package.version v;
  # The normal recipe intentionally inherits stdenv's --disable-static. Exercise
  # upstream's optional static libraries in a companion
  # build, without changing any published package's derivation or feature flags.
  staticPackage = package.overrideAttrs (_: {
    dontDisableStatic = true;
  });
  widths = [
    8
    16
    32
  ];
  apiExpected =
    width:
    let
      utfEnd =
        if width == 8 then
          "6"
        else if width == 16 then
          "3"
        else
          "2";
      classEnd =
        if package.version == "10.47" then
          (if width == 8 then "2" else "1")
        else if width == 8 then
          "13"
        else
          "5";
      unicode =
        if since "10.48" then
          "17.0.0"
        else if since "10.47" then
          "16.0.0"
        else
          "15.0.0";
    in
    ''
      width=${toString width} version=${package.version} unicode=${unicode} jit=1
    ''
    + (
      if since "10.47" then
        ''
          effective-linksize=${if width == 32 then "4" else "2"}
          next-match/effective-linksize=enabled
        ''
      else
        ''
          next-match/effective-linksize=pre-10.47
        ''
    )
    + ''
      utf interpreter=2:0-${utfEnd} jit=2:0-${utfEnd}
      lookbehind-912 interpreter=2:3-4 jit=${if since "10.48" then "2:3-4" else "-1:0-0"}
      mixed-class-841 interpreter=1:0-${classEnd} jit=1:0-${classEnd}
    '';
  expected = lib.removeSuffix "\n" (
    lib.concatMapStrings apiExpected widths + "posix captures/nomatch ok\n"
  );
  consumer =
    static:
    let
      p = if static then staticPackage else package;
      library =
        name:
        "${p}/lib/libpcre2-${name}${
          if static then ".a" else pkgs.stdenv.hostPlatform.extensions.sharedLibrary
        }";
      loaded =
        name:
        lib.optionalString (
          !static && pkgs.stdenv.hostPlatform.isLinux
        ) "-DEXPECTED_LIBRARY='\"${library name}\"' -ldl";
    in
    {
      inherit expected;
      extraInputs = [ package.tvp.cc ];
      script =
        lib.concatMapStrings (
          width:
          let
            w = toString width;
          in
          ''
            cc -std=c99 -Wall -Wextra -Werror -UNDEBUG -I${p}/include \
              -DPCRE2_CODE_UNIT_WIDTH=${w} ${loaded w} \
              ${./fixtures/api.c} ${library w} -Wl,-rpath,${p}/lib -o api-${w}
            ./api-${w}
            ${lib.optionalString (static && pkgs.stdenv.hostPlatform.isLinux) ''
              readelf -d api-${w} > dynamic
              if grep -q 'NEEDED.*libpcre2' dynamic; then exit 1; fi
            ''}
          ''
        ) widths
        + ''
          cc -std=c99 -Wall -Wextra -Werror -UNDEBUG -I${p}/include \
            ${loaded "posix"} ${
              lib.optionalString (
                !static && pkgs.stdenv.hostPlatform.isLinux
              ) "-DEXPECTED_ENGINE='\"${library "8"}\"'"
            } ${./fixtures/posix.c} \
            ${library "posix"} ${library "8"} -Wl,-rpath,${p}/lib -o posix
          ./posix
          ${lib.optionalString (static && pkgs.stdenv.hostPlatform.isLinux) ''
            readelf -d posix > dynamic
            if grep -q 'NEEDED.*libpcre2' dynamic; then exit 1; fi
          ''}
        '';
    };
in
{
  shared-api = consumer false;
  static-api = consumer true;
}
// lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
  elf-contract = {
    extraInputs = [ package.tvp.cc ];
    script = ''
      for width in 8 16 32 posix; do
        soname=libpcre2-$width.so.0
        if [ "$width" = posix ]; then soname=libpcre2-posix.so.3; fi
        readelf -d ${package}/lib/libpcre2-$width.so > dynamic
        grep -F "Library soname: [$soname]" dynamic > /dev/null
        readelf --dyn-syms --wide ${package}/lib/libpcre2-$width.so > symbols
        symbol=pcre2_config_$width
        if [ "$width" = posix ]; then symbol=pcre2_regcomp; fi
        ${
          if since "10.47" then
            ''
              grep -F "$symbol@@PCRE2_10.47" symbols > /dev/null
              if [ "$width" != posix ]; then
                grep -F "pcre2_next_match_$width@@PCRE2_10.47" symbols > /dev/null
              fi
            ''
          else
            ''
              grep -F "$symbol" symbols > /dev/null
              if grep -E 'pcre2_.*(@|next_match)' symbols > /dev/null; then exit 1; fi
            ''
        }
      done
      echo 'SONAME/symbol versions ok'
    '';
    expected = "SONAME/symbol versions ok";
  };
}
