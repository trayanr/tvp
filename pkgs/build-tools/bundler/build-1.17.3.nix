# Serves 1.17.3 onwards.
{
  lib,
  buildRubyGem,
  writeScript,

  version,
  sha256,

  ruby,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
let
  self = buildRubyGem rec {
    inherit ruby;
    name = "${gemName}-${version}";
    gemName = "bundler";
    inherit version;
    source.sha256 = sha256;
    dontPatchShebangs = true;

    # The generated wrapper calls Gem.activate_bin_path, which pins this exact
    # bundler. Rewriting it to Gem.bin_path drops the pin, and `require
    # "bundler"` then resolves to whichever bundler is newest on GEM_PATH —
    # Ruby ships one as a default gem, so bundler_1_17_3 served 2.1.2.

    passthru = {
      # buildRubyGem sets `name` but not `pname`.
      pname = gemName;
      inherit version;
      tvp.deps = {
        inherit ruby;
      };
      tests = mkTests self;

      updateScript = writeScript "gem-update-script" ''
        #!/usr/bin/env nix-shell
        #!nix-shell -i bash -p curl common-updater-scripts jq

        set -eu -o pipefail

        latest_version=$(curl -s https://rubygems.org/api/v1/gems/${gemName}.json | jq --raw-output .version)
        update-source-version ${gemName} "$latest_version"
      '';
    };

    meta = with lib; {
      description = "Manage your Ruby application's gem dependencies";
      homepage = "https://bundler.io";
      changelog = "https://github.com/rubygems/rubygems/blob/bundler-v${version}/bundler/CHANGELOG.md";
      license = licenses.mit;
      maintainers = with maintainers; [ anthonyroussel ];
      mainProgram = "bundler";
    };
  };
in
self
