{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  png ? null,
  zlib,
  bzip2 ? null,
  fontconfig ? null,
  freetype ? null,
  lcms2 ? null,
  libice ? null,
  libsm ? null,
  libtiff ? null,
  libwebp ? null,
  libx11 ? null,
  libxext ? null,
  libxml2 ? null,
  libxt ? null,
  libzip ? null,
  openjpeg ? null,
  perl ? null,
  xz ? null,
  zstd ? null,
  buildFeatures ? { },
  sourceCompression ? "xz",
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
  isMagick7 = lib.versionAtLeast final.version "7";
  # The lower bounds are the first packaged releases with each configure probe.
  atLeast =
    magick6: magick7: lib.versionAtLeast final.version (if isMagick7 then magick7 else magick6);
  delegates = {
    bzlib = final.bzip2;
    fontconfig = final.fontconfig;
    freetype = final.freetype;
    tiff = final.libtiff;
    xml = final.libxml2;
  }
  // lib.optionalAttrs (atLeast "6.6.0.10" "7.0.1.0") { lcms = final.lcms2; }
  // lib.optionalAttrs (atLeast "6.6.6.10" "7.0.1.0") { lzma = final.xz; }
  // lib.optionalAttrs (atLeast "6.6.8.10" "7.0.1.0") { webp = final.libwebp; }
  // lib.optionalAttrs (atLeast "6.8.8.10" "7.0.1.0") { openjp2 = final.openjpeg; }
  // lib.optionalAttrs (atLeast "6.9.10.13" "7.0.8.13") { zstd = final.zstd; }
  // lib.optionalAttrs (isMagick7 && lib.versionAtLeast final.version "7.0.10.62") {
    zip = final.libzip;
  };
  delegateFlag =
    name:
    if
      name == "lcms"
      && lib.versionAtLeast final.version "6.6.2.10"
      && lib.versionOlder final.version "6.9.1.10"
    then
      "lcms2"
    else
      name;
  delegateMacro =
    name: if name == "openjp2" then "LIBOPENJP2_DELEGATE" else "${lib.toUpper name}_DELEGATE";
  enabledDelegates = lib.filterAttrs (_: provider: provider != null) delegates;
  xmlIcu = enabledDelegates.xml.specification.icu or null;
  xLibraries = lib.optionals (final.libx11 != null) (
    lib.filter (provider: provider != null) [
      final.libx11
      final.libxext
      final.libxt
      final.libice
      final.libsm
    ]
  );
  enabledMacros =
    map delegateMacro (builtins.attrNames enabledDelegates)
    ++ lib.optional (xLibraries != [ ]) "X11_DELEGATE";
  toggle = flag: enabled: "--${if enabled then "enable" else "disable"}-${flag}";
  # These are the first releases with the upstream libjpeg-turbo guards.
  needsJpegGuards =
    lib.versionOlder final.version "6.9.12.76"
    || (lib.versionAtLeast final.version "7" && lib.versionOlder final.version "7.1.0.61");
  # These configure scripts treat an unset OpenCL probe as a found library.
  needsOpenclDisabled = lib.elem final.version [
    "6.9.10.66"
    "7.0.8.66"
  ];
  needsSourceFixes =
    lib.versionOlder final.version "6.7.5.10"
    || (lib.versionAtLeast final.version "6.8.7.10" && lib.versionOlder final.version "6.9.2.10")
    || (lib.versionAtLeast final.version "6.9.13.53" && lib.versionOlder final.version "6.9.13.62")
    || lib.elem final.version [
      "6.9.9.1"
      "6.9.10.81"
      "6.9.11.17"
      "7.1.0.52"
    ];
  needsCompileRepair =
    lib.versionOlder final.version "6.7.4.10"
    || lib.elem final.version [
      "6.9.12.9"
      "6.9.12.98"
      "7.0.8.17"
      "7.1.1.20"
    ];
  needsInstallRepair = lib.elem final.version [
    "6.8.3.10"
    "6.9.10.54"
  ];
  elfPaths = [
    "bin"
    "lib"
  ];
in
{
  pname = "imagemagick";
  # The installed configuration paths in MagickCore occupy compiled prefix slots.
  artifactName = "${final.pname}-${final.version}";
  inherit
    base
    src
    version
    jpeg
    png
    zlib
    bzip2
    fontconfig
    freetype
    lcms2
    libice
    libsm
    libtiff
    libwebp
    libx11
    libxext
    libxml2
    libxt
    libzip
    openjpeg
    perl
    xz
    zstd
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    jpeg = true;
    png = final.png != null;
    # Link the same coders into MagickCore instead of loading them as modules.
    modules = false;
    quantumDepth = 16;
    hdri = true;
    openmp = true;
    x11 = xLibraries != [ ];
  }
  // buildFeatures;
  sourceLayout.compression = sourceCompression;
  installedInterface = {
    cli = if isMagick7 then "magick" else "convert";
    wandHeader = if isMagick7 then "MagickWand/MagickWand.h" else "wand/MagickWand.h";
    perlModuleDirectory = if final.perl != null then "lib/perl5" else null;
    delegates = builtins.attrNames enabledDelegates;
  };
  environment = {
    tools = [
      tools.gnumake
      tools.pkg-config
      tools.sed
      tools.grep
      tools.gawk
      tools.diffutils
      tools.findutils
    ]
    ++ lib.optional (final.perl != null) final.perl
    # Older configure scripts call xml2-config for its include directory.
    ++ lib.optional (final.libxml2 != null) final.libxml2;
    libraries = [
      final.jpeg
      final.zlib
    ]
    ++ lib.optional (final.png != null) final.png
    ++ builtins.attrValues enabledDelegates
    ++ xLibraries;
  };
  # The XML and X11 delegate link flags also add their providers' libraries.
  runtime.libraries =
    final.environment.libraries
    ++ lib.optional (xmlIcu != null) xmlIcu
    ++ lib.optionals (final.libx11 != null) [
      final.libx11.specification.libxcb
      final.libx11.specification.libxau
      final.libx11.specification.libxdmcp
    ];
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.sourceLayout) compression;
    })
    (lib.optional needsJpegGuards {
      name = "imagemagick.jpeg-compatibility";
      cwd = "source";
      tools = [ tools.python ];
      run = "${tools.python}/bin/python3 -B ${./jpeg-compat.py}";
    })
    (lib.optional needsSourceFixes {
      name = "imagemagick.source-compatibility";
      cwd = "source";
      tools = [ tools.python ];
      run = "${tools.python}/bin/python3 -B ${./source-compat.py} ${lib.escapeShellArg final.version}";
    })
    (lib.optional needsCompileRepair {
      name = "imagemagick.compile-repair";
      cwd = "source";
      tools = [ tools.python ];
      run = "${tools.python}/bin/python3 -B ${./compile-compat.py} ${lib.escapeShellArg final.version}";
    })
    (lib.optional
      (
        final.lcms2 != null
        && lib.versionAtLeast final.version "6.6.2.10"
        && lib.versionOlder final.version "6.8.9.10"
      )
      (
        command "imagemagick.lcms-context" ''
          # Backport the 6.8.9 LCMS context casts for the error callback's image.
          file=magick/profile.c
          test "$(grep -Fc 'cmsCreateTransformTHR(image,' "$file")" = 1
          test "$(grep -Fc 'cmsOpenProfileFromMemTHR(image,' "$file")" = 2
          sed -i -e 's/cmsCreateTransformTHR(image,/cmsCreateTransformTHR((cmsContext) image,/' \
            -e 's/cmsOpenProfileFromMemTHR(image,/cmsOpenProfileFromMemTHR((cmsContext) image,/' "$file"
        ''
      )
    )
    (lib.optional (final.perl != null && final.version == "6.9.12.94") (
      command "imagemagick.perl-morphology-cast" ''
        # The generated PerlMagick XS template has an extra parenthesis.
        file=PerlMagick/quantum/quantum.xs.in
        test "$(grep -Fc 'method=(MorphologyMethod)) argument_list[2].integer_reference;' "$file")" = 1
        sed -i 's/method=(MorphologyMethod)) /method=(MorphologyMethod) /' "$file"
      ''
    ))
    (lib.optional (final.perl != null && final.version == "6.9.12.6") (
      command "imagemagick.perl-makefile-syntax" ''
        # Restore the missing terminator, as in the next upstream release.
        file=PerlMagick/default/Makefile.PL.in
        test "$(grep -c '^my [$]LIBS_magick = .*[^;]$' "$file")" = 1
        sed -i '/^my [$]LIBS_magick = /s/$/;/' "$file"
      ''
    ))
    (lib.optional (final.perl != null && final.version == "7.0.5.3") (
      command "imagemagick.perl-module-install-order" ''
        # The default subdirectory installs the generated Image::Magick module.
        # Keep the top-level XS build from writing a second copy to the same path.
        file=PerlMagick/Makefile.PL.in
        test -f PerlMagick/default/Magick.pm.in
        test "$(grep -Fxc '   # Module description' "$file")" = 1
        sed -i '/^   # Module description$/i\   PM => {},' "$file"
      ''
    ))
    (lib.optional (enabledDelegates ? webp && final.version == "6.8.3.10") (
      command "imagemagick.webp-probe" ''
        # Backport the next release's probe for the symbol exported by libwebp.
        test "$(grep -ow WebPPictureInit configure | wc -l)" = 4
        sed -i 's/WebPPictureInit/WebPPictureInitInternal/g' configure
      ''
    ))
    (lib.optional
      (lib.versionAtLeast final.version "6.5.6.10" && lib.versionOlder final.version "6.6.2.10")
      (
        command "imagemagick.remap-dither" ''
          # Match the 6.6.2 fix and assign the flag to the dither member.
          file=Magick++/lib/Magick++/STL.h
          test "$(grep -Fc 'quantizeInfo = dither_' "$file")" = 1
          sed -i 's/quantizeInfo = dither_/quantizeInfo.dither = dither_/' "$file"
        ''
      )
    )
    (lib.optional (final.version == "6.7.0.10") (
      command "imagemagick.png-filter" ''
        # The 6.7.1 branch makes these libpng filter choices exclusive.
        file=coders/png.c
        test "$(grep -Fxc '  if (mng_info->write_png_compression_filter == 7 ||' "$file")" = 1
        sed -i '/^  if (mng_info->write_png_compression_filter == 7 ||$/s/^  if/  else if/' "$file"
      ''
    ))
    (steps.prepareAutotools { name = "imagemagick.prepare"; })
    (command "imagemagick.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash SHELL=${tools.bash}/bin/bash
      set -- ${
        lib.escapeShellArgs (
          lib.mapAttrsToList (
            name: provider: "--${if provider != null then "with" else "without"}-${delegateFlag name}"
          ) delegates
        )
      }
      ${lib.optionalString isMagick7 ''
        if grep -Fq -- '  --enable-legacy-support ' configure; then
          set -- "$@" --enable-legacy-support
        fi
      ''}
      ${lib.optionalString (xLibraries != [ ]) ''
        set -- "$@" --with-x --x-includes=${final.libx11}/include --x-libraries=${final.libx11}/lib
      ''}
      ${lib.optionalString (final.perl != null) ''
        export PERL=${final.perl}/bin/perl
        set -- "$@" --with-perl "--with-perl-options=INSTALL_BASE=$out"
      ''}
      ${lib.optionalString needsOpenclDisabled "ax_cv_check_cl_libcl=no "}./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static \
        ${toggle "openmp" final.buildFeatures.openmp}${lib.optionalString needsOpenclDisabled " --disable-opencl"} \
        ${lib.optionalString (xLibraries == [ ]) "--without-x"} ${
          lib.optionalString (final.perl == null) "--without-perl"
        } \
        --with-quantum-depth=${toString final.buildFeatures.quantumDepth} \
        ${toggle "hdri" final.buildFeatures.hdri} --without-modules \
        ${if final.buildFeatures.jpeg then "--with-jpeg" else "--without-jpeg"} \
        ${if final.buildFeatures.png then "--with-png" else "--without-png"} --with-zlib "$@"
      for macro in ${lib.escapeShellArgs enabledMacros}; do
        grep -E "^#define $macro 1$" config/config.h
      done
    '')
    (command "imagemagick.build" make)
    (command "imagemagick.install" ''
      ${make} install
      test -x "$out/bin/convert"
      test -x "$out/bin/identify"
      ${lib.optionalString (final.perl != null) ''
        test -n "$(find "$out/${final.installedInterface.perlModuleDirectory}" -path '*/Image/Magick.pm' -print -quit)"
      ''}
    '')
    (steps.split "imagemagick.finalize")
    (outputs.copyArtifacts { })
    (lib.optional needsInstallRepair {
      name = "imagemagick.install-repair";
      tools = [ tools.python ];
      run = ''
        ${tools.python}/bin/python3 -B ${./installed-compat.py} \
          ${lib.escapeShellArg final.version} "$out" "$TVP_ARTIFACT_ROOT"
      '';
    })
    {
      name = "imagemagick.relocate";
      tools = [
        tools.python
        tools.patchelf
      ];
      run = ''
        ${tools.python}/bin/python3 -B ${../../../lib/relocate.py} "$out" "$TVP_ARTIFACT_ROOT" \
          ${tools.patchelf}/bin/patchelf
      '';
    }
    (outputs.shebangs {
      paths = [ "bin" ];
      names = [ "sh" ];
      interpreter = "${tools.bash}/bin/bash";
    })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.strip { paths = elfPaths; })
    (outputs.rpaths {
      inherit base;
      paths = elfPaths;
      libraries = final.runtime.libraries;
    })
    (lib.optional (final.perl != null) {
      name = "imagemagick.perl-runtime";
      tools = [
        tools.patchelf
        tools.grep
      ];
      run = ''
        perlArchlib=$(${final.perl}/bin/perl -MConfig -e 'print $Config{archlibexp}')
        shopt -s globstar nullglob
        modules=("$out/${final.installedInterface.perlModuleDirectory}"/**/auto/Image/**/*.so)
        test "''${#modules[@]}" -gt 0
        for module in "''${modules[@]}"; do
          ${tools.patchelf}/bin/patchelf --add-rpath "$out/lib" "$module"
          if ${tools.patchelf}/bin/patchelf --print-needed "$module" | grep -q '^libperl\.so'; then
            ${tools.patchelf}/bin/patchelf --add-rpath "$perlArchlib/CORE" "$module"
          fi
        done
      '';
    })
    (outputs.development { libraries = final.environment.libraries; })
    (outputs.checkPaths { paths = elfPaths; })
  ];
  meta = {
    description = "ImageMagick image conversion and the MagickCore and MagickWand APIs";
    homepage = "https://imagemagick.org/";
    license = lib.licenses.imagemagick;
    platforms = [ "x86_64-linux" ];
    mainProgram = final.installedInterface.cli;
  };
}
