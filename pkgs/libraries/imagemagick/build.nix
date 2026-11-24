{
  tvp,
  lib,
  base,
  src,
  version,
  jpeg,
  png ? null,
  zlib,
  sourceCompression ? "xz",
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  make = ''${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash'';
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
    ;
  inherit (tools) bash coreutils;
  buildFeatures = {
    jpeg = true;
    png = final.png != null;
    modules = false;
    quantumDepth = 16;
    hdri = false;
  };
  sourceLayout.compression = sourceCompression;
  installedInterface = {
    cli = if lib.versionAtLeast final.version "7" then "magick" else "convert";
    wandHeader =
      if lib.versionAtLeast final.version "7" then "MagickWand/MagickWand.h" else "wand/MagickWand.h";
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
    ];
    libraries = [
      final.jpeg
      final.zlib
    ]
    ++ lib.optional (final.png != null) final.png;
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      inherit (final.sourceLayout) compression;
    })
    (lib.optional needsJpegGuards {
      name = "imagemagick.jpeg-compatibility";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./jpeg-compat.py}'';
    })
    (lib.optional needsSourceFixes {
      name = "imagemagick.source-compatibility";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./source-compat.py} ${lib.escapeShellArg final.version}'';
    })
    (lib.optional needsCompileRepair {
      name = "imagemagick.compile-repair";
      cwd = "source";
      tools = [ tools.python ];
      run = ''${tools.python}/bin/python3 -B ${./compile-compat.py} ${lib.escapeShellArg final.version}'';
    })
    (lib.optional (lib.versionAtLeast final.version "6.5.6.10" && lib.versionOlder final.version "6.6.2.10") (
      command "imagemagick.remap-dither" ''
        # Match the 6.6.2 fix and assign the flag to the dither member.
        file=Magick++/lib/Magick++/STL.h
        test "$(grep -Fc 'quantizeInfo = dither_' "$file")" = 1
        sed -i 's/quantizeInfo = dither_/quantizeInfo.dither = dither_/' "$file"
      ''
    ))
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
      ${lib.optionalString needsOpenclDisabled "ax_cv_check_cl_libcl=no "}./configure --prefix="$out" --libdir="$out/lib" --enable-shared --disable-static \
        --disable-openmp --without-x --without-perl${lib.optionalString needsOpenclDisabled " --disable-opencl"} \
        --with-quantum-depth=${toString final.buildFeatures.quantumDepth} \
        ${if final.buildFeatures.hdri then "--enable-hdri" else "--disable-hdri"} \
        ${if final.buildFeatures.modules then "--with-modules" else "--without-modules"} \
        ${if final.buildFeatures.jpeg then "--with-jpeg" else "--without-jpeg"} \
        ${if final.buildFeatures.png then "--with-png" else "--without-png"} --with-zlib
    '')
    (command "imagemagick.build" make)
    (command "imagemagick.install" "${make} install")
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
