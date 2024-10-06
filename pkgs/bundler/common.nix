{ lib, buildRubyGem, ruby, writeScript, version, sha256}:

buildRubyGem rec {
  inherit ruby;
  # ruby = builtins.trace args.ruby.version args.ruby;
  name = "${gemName}-${version}";
  gemName = "bundler";
  inherit version;
  source.sha256 = sha256;
  dontPatchShebangs = true;

  postFixup = ''
    sed -i -e "s/activate_bin_path/bin_path/g" $out/bin/bundle
	# maybe wrapProgram and --set PATH to make sure the ruby version is the one from this file and not the user ENV
  '';

  passthru = {
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
}


