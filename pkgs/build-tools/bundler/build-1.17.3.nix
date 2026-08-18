# Serves 1.17.3 onwards.
{
  lib,
  stdenv,
  fetchurl,

  version,
  sha256,

  ruby,

  # Supplied by default.nix. A fork that drops this argument fails to evaluate.
  mkTests,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "bundler";
  inherit version;

  src = fetchurl {
    url = "https://rubygems.org/gems/bundler-${version}.gem";
    inherit sha256;
  };

  # The .gem is what `gem install` consumes; there is nothing to unpack.
  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ ruby ];
  buildInputs = [ ruby ];

  installPhase = ''
    runHook preInstall

    export GEM_HOME="$out/${ruby.gemPath}"
    mkdir -p "$GEM_HOME"

    gem install \
      --local \
      --force \
      --ignore-dependencies \
      --install-dir "$GEM_HOME" \
      --build-root / \
      --no-env-shebang \
      --no-document \
      "$src"

    # A copy of the input, rewritten on every install.
    rm -rf "$GEM_HOME/cache"

    ruby ${./binstubs.rb} \
      "${ruby}/bin/ruby" "$out" "$GEM_HOME" "${ruby}/${ruby.gemPath}"

    runHook postInstall
  '';

  passthru = {
    tvp.deps = {
      inherit ruby;
    };

    tests = mkTests finalAttrs.finalPackage;
  };

  meta = {
    description = "Manage your Ruby application's gem dependencies";
    homepage = "https://bundler.io";
    changelog = "https://github.com/rubygems/rubygems/blob/bundler-v${version}/bundler/CHANGELOG.md";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "bundle";
  };
})
