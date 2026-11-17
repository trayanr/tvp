# Package family registration, public selectors and variant projections.
{ pkgs, tvp }:
let
  catalogue = tvp.lib.packages.mergeNamespaces {
    sdks = import ./sdks { inherit pkgs tvp; };
    servers = import ./servers { inherit pkgs tvp; };
    data = import ./data { inherit pkgs tvp; };
    compilers = import ./compilers { inherit pkgs tvp; };
    libraries = import ./libraries { inherit pkgs tvp; };
    runtimes = import ./runtimes { inherit pkgs tvp; };
    build-tools = import ./build-tools { inherit pkgs tvp; };
  };
  # An alias may shadow a canonical name here, deliberately: `openssl_1_1_1` is
  # the newest 1.1.1x. The shadowed release keeps its exact name in `canonical`,
  # which is what every tool and check reads.
  canonical = catalogue.canonical;
  packages =
    pkgs.lib.mapAttrs (
      selector: package:
      tvp.lib.packages.tagSelection (
        package.__tvpSelection
        // {
          namespace = "packages";
          inherit selector;
          publicFallback = true;
        }
      ) package
    ) canonical
    // catalogue.aliases;
  variants = catalogue.variants;
  variantPackages = tvp.lib.packages.merge (
    pkgs.lib.mapAttrs (
      profile: entries:
      pkgs.lib.mapAttrs' (
        name: package: pkgs.lib.nameValuePair "variant-${profile}-${name}" package
      ) entries
    ) variants
  );

in
catalogue // { inherit packages variantPackages; }
