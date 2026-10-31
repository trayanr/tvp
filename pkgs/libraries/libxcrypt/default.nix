{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  defs = tvpLib.packages.mkDefs {
    "4.4.36" = {
      builder = ./build-4.4.36.nix;
      base = tvp.bases.default;
      deps.perl = tvp.packages.perl_5_44_0;
      # ascii64 retains its explicit NUL and discards a redundant implicit NUL.
      # GCC15 adds this Wextra diagnostic; keep it visible and all other Werror.
      opts.compileFlags = [ "-Wno-error=unterminated-string-initialization" ];
    };
    "4.5.0" = {
      builder = ./build-4.4.36.nix;
      base = tvp.bases.default;
      deps.perl = tvp.packages.perl_5_44_0;
    };

  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."4.4.36";
      releases = {
        "4.4.36" = "sha256-5eH0yu4KAd4q7ibjE4gH1tPKK45nKHlm0f79ZeH9iUM=";

      };
    }
    {
      def = defs."4.5.0";
      releases = {
        "4.5.0" = "sha256-gl52Tk/y5jBK24FM2ilwdLIi1UoE7b2OvHz1j8OvhX0=";
        "4.5.1" = "sha256-6bRqYjl8FTcpNfanXcOSnGIWHyYgvnt/V/A9aRAsGoY=";
        "4.5.2" = "sha256-cVE6McAaQovM1TZ6Mv2V8RXW2sUPtbYMd51ceUKuwHE=";
      };
    }
  ];
  pname = "libxcrypt";
  packageArgs = {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests =
      package:
      import ./tests {
        inherit pkgs tvpLib package;
        baseline = tvp.canonical.libxcrypt_4_4_36;
      };
    packageMeta.upstream = {
      type = "git-tags";
      url = "https://github.com/besser82/libxcrypt";
      normalise =
        tag:
        let
          matched = builtins.match "v([0-9]+\\.[0-9]+\\.[0-9]+)" tag;
        in
        if matched == null then null else builtins.head matched;
    };
  };
  canonical = tvpLib.packages.mkVersions packageArgs;

in
{
  recipes.${pname} = packageArgs;
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
