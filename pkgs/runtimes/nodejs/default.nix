{ pkgs, tvp }:
let
  pname = "nodejs";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-owned-25.4.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Upstream configure accepts Python 3.14 and rejects Python 3.15.
          python = tvp.packages.python_3_14;
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
      releases = {
        "25.4.0" = "sha256-BONlqtzXv0zxpgAXI+pBA1v7EY14+KjuIFSzf8XLZ9Y=";
        "25.5.0" = "sha256-fjXvr2PI/nc3uMYnkuxUflqVpp8fgT/PuihWauzJ/ZI=";
        "25.6.0" = "sha256-nbaEjIArGYHA+utxpbjMeZE/gqdH9/HVAmDG0veB734=";
        "25.6.1" = "sha256-z3Vngci03F7gMPh9351RuNW/IZrVbL2YVcSjvcgyx44=";
        "25.7.0" = "sha256-jxPffo95w+jyJ61xPHVFkik8mPcOnino/O6XTmKgAOE=";
        "25.8.0" = "sha256-XQBCnLhWzHIgDsbAjozdp16pYYJW3o2Jn6BJwj9KLu4=";
        "25.8.1" = "sha256-CyWytfq4Dqi0P9qnRR9QBlVx4L/aJSTKQr3ouY/k0tk=";
        "25.8.2" = "sha256-PvsZ51fcWbshYyUHIA0t54I2nVImpolV6Tcskl/fJHE=";
        "25.9.0" = "sha256-j3ivPuVfsnhmi1+AHbWL0aOOoWExjrXOISjdvJzYE6o=";
        "26.0.0" = "sha256-/LXlwGpcLsnmaYASSGV6r6oikfh2Dax7+2Ofh4MYxZI=";
        "26.1.0" = "sha256-d5oTZIiVddROAhWtw4GAa70NlDdVe1mJPhcvW501qZA=";
        "26.2.0" = "sha256-6oK+fbQY9Us+8VOgLUTU9nSEZvR2WugLxITzSvQN9hA=";
        "26.3.0" = "sha256-MZrV19IMxiLlXrdbnxolRrd6CL1GK2cDDQyJMWwsI0k=";
        "26.3.1" = "sha256-l5ubgwio0tSifGYu1QRIyF+XDA/U9c6LmOjaeMRB8rw=";
        "26.4.0" = "sha256-ns6zYhAkBp2RA1tUcdLr6GqgTSLb66cqeC6vNv+Rg6w=";
        "26.5.0" = "sha256-DheUcAl+JHoMB2m3fME1n8PhuvBobfibr+H7SMsYh/Q=";
        "26.5.1" = "sha256-33dwqamTRvi3O6bTGtib1vhotRxzh8NifctEygZfSUg=";
        "26.6.0" = "sha256-7LbuyBJQXJKSUpCHokNuxsiR/+DjqJeDNBbl10NtZZ8=";
        "26.7.0" = "sha256-5rGCy+6rAy0QgspKxP4V46V95pHTveeOz4p2H9Vu41Y=";
        "26.8.0" = "sha256-IodhPKpx+auN/0y+x9oy8Prj6IB6aHand2SswW1Mykw=";
        "26.8.1" = "sha256-0WmIMqGhDwUM3aBEo+PWp0gkaBHi57yJupqL1pPcRfI=";
        "26.8.2" = "sha256-NrN79e5NCSudnf8tGpCxRE+LRT7d9v+Wyr3ruX0y9B0=";
        "26.9.0" = "sha256-R7lw2IURtCnlh7dA+nMxdpCdKiAFopZi8BsFIF9YRos=";
        "26.10.0" = "sha256-ezpUbTPLfhWkO916V+C+XV/V/8VT5uTBIAM+ZvC6IMU=";
        "26.11.0" = "sha256-qq2SQnBFJBCeiNSL57t7eUNIbZMedAo1LALpfhB/GMk=";
        "26.11.1" = "sha256-LHmjwQlcfaTFSchOkLLSjfVHkxWrbQr/m8cdz0yd8eA=";
      };
    }
    {
      def = {
        builder = ./build-owned-25.4.0.nix;
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
      releases = {
        "26.12.0" = "sha256-zln5A43aDmN2VvscNs9SwHxjeSL9gdQZ27ouwSmvvTU=";
        "26.12.1" = "sha256-BT47KWhZttjZP5nvl/qc7BxO4XHHKWgQDGSZeMHb04w=";
        "26.13.0" = "sha256-Jj9jns+noXtJQ412zb+a/3MXnjx8t4naabkAcYQn+i4=";
        "26.13.1" = "sha256-p/YgT/Y7aizSdNSJAyhau4btU6mQcOUy1ML9eHRX2eY=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
      discovery = {
        type = "json-index";
        url = "https://nodejs.org/dist/index.json";
        selector = ".[].version";
        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
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
