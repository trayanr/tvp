{
  tvp,
  lib,
  base,
  src,
  version,
  cairo,
  cargo,
  cargoLock,
  freetype,
  gdk-pixbuf,
  glib,
  harfbuzz,
  libxml2,
  pango,
  rustc,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
  command = steps.command { environment = final.environment; };
  paths = [
    "bin"
    "lib"
  ];
  packages = (builtins.fromTOML (builtins.readFile cargoLock)).package;
  crates = map (
    {
      name,
      version,
      source,
      checksum,
      ...
    }:
    assert source == "registry+https://github.com/rust-lang/crates.io-index";
    assert builtins.match "[A-Za-z0-9_-]+" name != null;
    assert builtins.match "[0-9][A-Za-z0-9.+_-]*" version != null;
    let
      archive = tvp.lib.sources.archive {
        url = "https://static.crates.io/crates/${name}/${name}-${version}.crate";
      };
    in
    {
      directory = "${name}-${version}";
      inherit checksum;
      file = toString (archive {
        inherit version;
        sha256 = checksum;
      });
    }
  ) (builtins.filter (package: package ? source) packages);
  make = ''
    export CARGO_HOME="$TVP_SOURCE_ROOT/cargo-home" CARGO_NET_OFFLINE=true
    export CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER="$CC"
    ${tools.gnumake}/bin/make -j"$NIX_BUILD_CORES" SHELL=${tools.bash}/bin/bash
  '';
in
{
  pname = "librsvg";
  inherit
    base
    src
    version
    cairo
    cargo
    cargoLock
    freetype
    gdk-pixbuf
    glib
    harfbuzz
    libxml2
    pango
    rustc
    ;
  inherit (tools) bash coreutils;
  outputs = [ "out" ];
  environment = {
    tools = [
      tools.gnumake
      tools.pkg-config
      tools.python
      tools.gawk
      tools.grep
      tools.sed
      tools.diffutils
      tools.findutils
      final.glib
      final.rustc
      final.cargo
    ];
    libraries = with final; [
      cairo
      freetype
      gdk-pixbuf
      glib
      harfbuzz
      libxml2
      pango
    ];
  };
  runtime.libraries = final.environment.libraries;
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "xz";
    })
    (command "librsvg.vendor" ''
      cmp Cargo.lock ${cargoLock}
      printf '%s' ${lib.escapeShellArg (builtins.toJSON crates)} > vendor-manifest.json
      ${tools.python}/bin/python3 -B ${./vendor-crates.py} vendor-manifest.json
    '')
    (steps.prepareAutotools { name = "librsvg.prepare"; })
    (command "librsvg.configure" ''
      export CONFIG_SHELL=${tools.bash}/bin/bash
      export LDFLAGS="''${LDFLAGS-} -Wl,-rpath,$out/lib"
      "$CONFIG_SHELL" ./configure --prefix="$out" --libdir="$out/lib" \
        --enable-shared --disable-static --disable-gtk-doc --enable-introspection=no \
        --enable-vala=no --disable-pixbuf-loader
    '')
    (command "librsvg.build" make)
    (command "librsvg.install" "${make} install")
    (steps.split "librsvg.finalize")
    (outputs.copyArtifacts { outputs = final.outputs; })
    (outputs.libtool { paths = [ "lib" ]; })
    (outputs.relocateText { paths = [ "lib/pkgconfig" ]; })
    (outputs.strip { inherit paths; })
    (outputs.rpaths {
      inherit paths;
      libraries = final.runtime.libraries;
    })
    (outputs.development {
      libraries = [
        final.glib
        final.cairo
        final.gdk-pixbuf
      ];
    })
    (outputs.checkPaths { inherit paths; })
  ];
  meta = {
    description = "SVG renderer for Cairo with an installed command-line converter";
    homepage = "https://gnome.pages.gitlab.gnome.org/librsvg/";
    license = lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
  };
}
