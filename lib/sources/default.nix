# Immutable, root-preserving source inputs; not an installed-package constructor.
{ lib }:
{
  fetchArchive =
    {
      url,
      sha256,
      bash,
      curl,
      tar,
      gzip,
      coreutils,
      python,
      certificates,
      system ? "x86_64-linux",
      name ? "source",
    }:
    assert
      builtins.isString url
      && (
        builtins.match "https://[^[:space:]]+" url != null
        || (
          builtins.hasContext url
          &&
            builtins.match "file:///nix/store/[a-z0-9]{32}-[A-Za-z0-9+._=-]+(/[A-Za-z0-9+._=-]+)*" url != null
          && builtins.all (part: part != "." && part != "..") (lib.splitString "/" url)
          && builtins.match ".*[[:space:]].*" url == null
        )
      );
    assert builtins.isString sha256 && sha256 != "";
    assert builtins.match "[A-Za-z0-9][A-Za-z0-9._+-]*" name != null;
    builtins.derivation {
      inherit name system;
      builder = "${bash}/bin/bash";
      args = [
        "-euc"
        ''
          export PATH=${lib.escapeShellArg "${coreutils}/bin:${tar}/bin:${gzip}/bin"}
          ${curl}/bin/curl --disable --fail --location --proto '=https,file' --proto-redir '=https' \
            --cacert ${lib.escapeShellArg "${certificates}/etc/ssl/certs/ca-bundle.crt"} \
            --output archive.tar.gz -- ${lib.escapeShellArg url}
          ${python}/bin/python3 -B ${./validate-archive.py} archive.tar.gz
          mkdir "$out"
          ${tar}/bin/tar --extract --gzip --file archive.tar.gz --directory "$out" \
            --no-same-owner --delay-directory-restore
          chmod -R u+w "$out"
        ''
      ];
      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = sha256;
      preferLocalBuild = true;
      impureEnvVars = [
        "https_proxy"
        "http_proxy"
        "all_proxy"
        "no_proxy"
      ];
    };
}
