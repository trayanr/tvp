# A fixed-output checkout of the pinned Savannah revision using TVP Git.
{
  repository,
  revision,
  sha256,
  system,
  bash,
  coreutils,
  git,
  ca-certificates,
}:
builtins.derivation {
  name = "config-${builtins.substring 0 7 revision}";
  inherit system;
  builder = "${bash}/bin/bash";
  args = [
    "-euc"
    ''
      export PATH=${coreutils}/bin:${git}/bin
      export HOME="$PWD/home"
      export GIT_CONFIG_NOSYSTEM=1
      export GIT_SSL_CAINFO=${ca-certificates}/etc/ssl/certs/ca-bundle.crt
      mkdir "$HOME" "$out"
      git -C "$out" init --quiet
      git -C "$out" fetch --quiet --no-tags --depth=1 "${repository}" "${revision}" ||
        git -C "$out" fetch --quiet --no-tags "${repository}" refs/heads/master
      git -C "$out" checkout --quiet --detach "${revision}"
      rm -rf -- "$out/.git"
    ''
  ];
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;
  preferLocalBuild = true;
  impureEnvVars = [
    "https_proxy"
    "http_proxy"
    "all_proxy"
    "no_proxy"
  ];
}
