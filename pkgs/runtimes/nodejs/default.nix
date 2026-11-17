{ pkgs, tvp }:
let
  pname = "nodejs";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-26.13.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          python = tvp.packages.python_3;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases."26.13.0" = "sha256-Jj9jns+noXtJQ412zb+a/3MXnjx8t4naabkAcYQn+i4=";
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
    };
    tests = (import ./tests/provider-context.nix { inherit pkgs; });
    testDeps.shell = tvp.packages.bash_5;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.nodejs = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
