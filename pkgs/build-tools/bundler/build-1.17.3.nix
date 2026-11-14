# 1.17.3 onwards: local source gem installation; pinned version wrappers after the split.
{
  tvp,
  lib,
  base,
  src,
  version,
  ruby,
  offlineControls ? false,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  selected = final.ruby;
  runtimeRuby = final.runtime.ruby;
  environment = final.base.environment final.environment;
in
{
  pname = "bundler";
  inherit
    base
    src
    version
    ;
  inherit (tools) bash coreutils;
  inherit ruby offlineControls;
  dependencyProviders = {
    ruby = final.runtime.ruby;
  };
  installedInterface.offlineControls = final.offlineControls;
  environment = {
    tools = [
      selected
      tools.findutils
    ];
    libraries = [ ];
  };
  runtime = {
    ruby = final.ruby;
    libraries = [ final.runtime.ruby ];
  };
  plan = steps.sequence [
    (
      environment
      // {
        name = "bundler.install";
        run = ''
          export HOME="$TMPDIR"
          unset GEM_PATH RUBYLIB
          export GEM_HOME="$out/${selected.gemPath}"
          mkdir -p "$GEM_HOME"
          ${selected}/bin/gem install --local --force --ignore-dependencies \
            --install-dir "$GEM_HOME" --build-root / --no-env-shebang --no-document ${final.src}
          rm -rf "$GEM_HOME/cache"
          ${tools.findutils}/bin/find "$GEM_HOME/gems" -path '*/man/*' -name '*.[1-9]' > manuals
          while IFS= read -r page; do
            install -Dm444 "$page" "$out/share/man/man''${page##*.}/''${page##*/}"
          done < manuals
        '';
      }
    )
    (steps.split "bundler.finalize")
    (outputs.copyArtifacts { })
    (outputs.relocateText {
      # Gem executables live under lib; top-level bin is created by wrappers below.
      paths = [ "lib" ];
    })
    {
      name = "bundler.wrappers";
      tools = [ runtimeRuby ];
      run = ''
        ${runtimeRuby}/bin/ruby ${./binstubs.rb} "${runtimeRuby}/bin/ruby" "$out" "$out/${final.ruby.gemPath}" "${runtimeRuby}/${runtimeRuby.gemPath}"
      '';
    }
    {
      name = "bundler.manuals";
      tools = [
        tools.findutils
        tools.gzip
      ];
      run = ''
        find "$out/share/man" -type f > manuals
        while IFS= read -r page; do ${tools.gzip}/bin/gzip -n -9 "$page"; done < manuals
      '';
    }
    (outputs.checkPaths {
      paths = [ "bin" ];
    })
  ];
  buildEnvironment =
    { tool, ... }:
    {
      paths = {
        GEM_PATH = {
          separator = ":";
          entries = [
            "${tool}/${selected.gemPath}"
            "${runtimeRuby}/${runtimeRuby.gemPath}"
          ];
        };
        RUBYLIB = {
          separator = ":";
          entries = [ "${tool}/${selected.gemPath}/gems/bundler-${final.version}/lib" ];
        };
      };
    };
  passthru = {
    rubyDevelopment = {
      gemDirectories = [ selected.gemPath ];
      siteDirectories = [ "${selected.gemPath}/gems/bundler-${final.version}/lib" ];
    };
  };
  meta = {
    description = "Manage your Ruby application's gem dependencies";
    homepage = "https://bundler.io";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "bundle";
  };
}
