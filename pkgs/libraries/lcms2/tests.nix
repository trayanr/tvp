{ package, context, ... }:
let
  inherit (package.specification.base) tools;
in
context.mkSuite {
  inherit package;
  tools = [ tools.pkg-config ];
  libraries = [ package ];
  tests = {
    pkg-config = {
      script = "pkg-config --modversion lcms2";
      expected = package.version;
    };
    profile = {
      script = ''
        cat > profile.c <<'EOF'
        #include <lcms2.h>
        #include <stdio.h>
        int main(void) {
          cmsHPROFILE profile = cmsCreate_sRGBProfile();
          if (!profile || cmsGetColorSpace(profile) != cmsSigRgbData)
            return 1;
          cmsCloseProfile(profile);
          puts("sRGB");
          return 0;
        }
        EOF
        cc $(pkg-config --cflags lcms2) profile.c $(pkg-config --libs lcms2) -o profile
        ./profile
      '';
      expected = "sRGB";
    };
  };
}
