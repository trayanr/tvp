# Real public registry gems exercise TVP-owned native libraries in one process.
{ tvp }:
let
  ruby = tvp.canonical.ruby_2_7_0;
  archive =
    name: version: sha256:
    builtins.fetchurl {
      url = "https://rubygems.org/gems/${name}-${version}.gem";
      inherit sha256;
    };
  gem =
    name: version: sha256: dependencies:
    tvp.lib.ruby.buildGem {
      inherit
        tvp
        ruby
        name
        version
        dependencies
        ;
      src = archive name version sha256;
    };
  miniPortile =
    gem "mini_portile2" "2.8.9" "12f2830x7pq3kj0v8nz0zjvaw02sv01bqs1zwdrc04704kwcgmqc"
      [ ];
  racc = gem "racc" "1.8.1" "0byn0c9nkahsl93y9ln5bysq4j31q8xkf2ws42swighxd4lnjzsa" [ ];
  observer = gem "observer" "0.1.2" "1b2h1642jy1xrgyakyzz6bkq43gwp8yvxrs8sww12rms65qi18yq" [ ];
  pkgConfig = gem "pkg-config" "1.6.2" "0ddyqmc56r0vsgs9p17bb3v6q5j2xv51y95ad8p3mr60cm2006z0" [ ];
  pg = (gem "pg" "0.21.0" "00vhasqwc4f98qb4wxqn2h07fjwzhp5lwyi41j2gndi2g02wrdqh" [ ]).override {
    postgresql = tvp.canonical.postgresql_11_9;
  };
  nokogiri = gem "nokogiri" "1.15.7" "16w64l83ycfwbaqyw06j8c8l8r30xy33lkv761516byix5nzl3ls" [
    miniPortile
    racc
  ];
  rmagick =
    (gem "rmagick" "5.5.0" "1wp6bw6c2y2125bbkm7xgp11ivjb7a9qidj46l26fy4h410fpvk8" [
      observer
      pkgConfig
    ]).override
      {
        # Enable ImageMagick's XML/SVG support with the same XML library that
        # Nokogiri loads into this Ruby process.
        imagemagick = tvp.packages.imagemagick_7.override {
          libxml2 = nokogiri.nativeProviders.libxml2;
        };
      };
  gemPath = builtins.concatStringsSep ":" (
    map (package: "${package}/${ruby.gemPath}") [
      pg
      nokogiri
      rmagick
      miniPortile
      racc
      observer
      pkgConfig
      ruby
    ]
  );
in
ruby.testContext.mkTest {
  package = pg;
  name = "native-providers";
  tools = [ ruby ];
  script = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    unset RUBYLIB BUNDLE_GEMFILE BUNDLE_PATH
    export GEM_HOME=${pg}/${ruby.gemPath}
    export GEM_PATH=${gemPath}
    ${ruby}/bin/ruby ${./native-providers.rb}
  '';
  expected = "native-providers-ok";
}
