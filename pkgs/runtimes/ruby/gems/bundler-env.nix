# Assemble project gem derivations with the selected Ruby and frozen Bundler.
{
  lib,
  fetchGit ? null,
}:
{
  tvp,
  ruby,
  bundler,
  gemfile,
  lockfile,
  gemset,
  groups ? [ "default" ],
  gemConfig ? { },
  sourceOverrides ? { },
  name ? "ruby-bundle",
  src ? null,
}:
let
  fail = message: throw "TVP Ruby bundle: ${message}";
  gitSource =
    gemName: source:
    let
      url = source.url or (fail "missing Git URL for ${gemName}");
      rev = source.rev or (fail "missing Git revision for ${gemName}");
      sha256 = source.sha256 or (fail "missing Git source hash for ${gemName}");
      fetchSubmodules = source.fetchSubmodules or false;
      repository = builtins.baseNameOf (lib.removeSuffix ".git" url);
      storeRepository = lib.removePrefix "file://" url;
      immutableLocalRepository =
        builtins.match "file:///nix/store/[a-z0-9]{32}-[A-Za-z0-9+._=-]+(/[A-Za-z0-9+._=-]+)*" url != null
        && lib.all (part: part != "." && part != "..") (lib.splitString "/" storeRepository);
      fetched = fetchGit {
        name = "${repository}-${builtins.substring 0 7 rev}";
        inherit
          url
          rev
          sha256
          fetchSubmodules
          ;
      };
    in
    assert builtins.isString url && url != "" || fail "invalid Git URL for ${gemName}";
    assert
      builtins.isString rev && builtins.match "([0-9a-fA-F]{40}|[0-9a-fA-F]{64})" rev != null
      || fail "Git revision for ${gemName} must be a full commit hash";
    assert builtins.isString sha256 && sha256 != "" || fail "missing Git source hash for ${gemName}";
    assert builtins.isBool fetchSubmodules || fail "fetchSubmodules for ${gemName} must be a boolean";
    assert
      fetchGit != null
      || fail "Git fetching is unavailable; use the full TVP package context or provide sourceOverrides.${gemName}";
    if immutableLocalRepository then
      # Build users do not own root-owned store inputs. Trust only this exact
      # immutable repository. Git's local transport strips GIT_CONFIG_COUNT,
      # so use an isolated config file inherited by the upload-pack process.
      fetched.overrideAttrs (_: {
        GIT_CONFIG_GLOBAL = builtins.toFile "ruby-git-store-source-config" ''
          [safe]
            directory = ${storeRepository}
        '';
      })
    else
      fetched;
  recipe =
    {
      base,
      ruby,
      bundler,
      gemfile,
      lockfile,
      gemset,
      groups,
      gemConfig,
      sourceOverrides,
      src,
    }:
    final:
    let
      context = tvp.builder.forBase final.base;
      inherit (context) tools;
      selectedBundler = final.bundler.override { ruby = final.ruby; };
      entries = if builtins.isAttrs final.gemset then final.gemset else import final.gemset;
      selectedNames = builtins.attrNames (
        lib.filterAttrs (
          _: entry: lib.intersectLists final.groups (entry.groups or [ "default" ]) != [ ]
        ) entries
      );
      closure = lib.genericClosure {
        startSet = map (key: { inherit key; }) selectedNames;
        operator =
          item:
          if !(builtins.hasAttr item.key entries) then
            fail "missing gem ${item.key} in gemset"
          else
            map (key: { inherit key; }) (entries.${item.key}.dependencies or [ ]);
      };
      packages = lib.genAttrs (map (item: item.key) closure) (
        gemName:
        let
          entry = entries.${gemName};
          source = entry.source or { };
          type = source.type or "gem";
          configuration = final.gemConfig.${gemName} or { };
          platform = configuration.platform or (entry.platform or "ruby");
          resolvedSource =
            final.sourceOverrides.${gemName} or (
              if type == "gem" then
                let
                  remote = lib.head (source.remotes or [ "https://rubygems.org" ]);
                in
                builtins.fetchurl {
                  url = "${lib.removeSuffix "/" remote}/gems/${gemName}-${entry.version}${
                    lib.optionalString (platform != "ruby") "-${platform}"
                  }.gem";
                  sha256 = source.sha256 or (fail "missing source hash for ${gemName}");
                }
              else if type == "git" then
                gitSource gemName source
              else
                fail "provide sourceOverrides.${gemName} for ${type} sources"
            );
        in
        tvp.lib.ruby.buildGem (
          {
            inherit tvp;
            ruby = final.ruby;
            name = gemName;
            inherit (entry) version;
            inherit platform;
            src = resolvedSource;
            sourceType =
              if type == "gem" then
                "gem"
              else if type == "git" then
                "git"
              else
                "source";
            dependencies = map (dependency: final.gems.${dependency}) (entry.dependencies or [ ]);
          }
          // configuration
        )
      );
      excludedGroups = lib.subtractLists final.groups (
        lib.unique (builtins.concatMap (entry: entry.groups or [ "default" ]) (builtins.attrValues entries))
      );
      manifest = builtins.toJSON {
        ruby = toString final.ruby;
        rubyGemPath = final.ruby.gemPath;
        bundler = toString selectedBundler;
        bundlerVersion = selectedBundler.version;
        shell = "${tools.bash}/bin/bash";
        inherit excludedGroups;
        packages = lib.mapAttrsToList (gemName: package: {
          name = gemName;
          inherit (package) version;
          home = "${package}/${package.gemPath}";
          directory = "${package}/${package.gemPath}/gems/${package.fullName}";
          specification = "${package}/${package.gemSpecPath}";
        }) final.gems;
      };
    in
    {
      pname = name;
      version = final.ruby.version;
      inherit
        base
        ruby
        bundler
        gemfile
        lockfile
        gemset
        groups
        gemConfig
        sourceOverrides
        src
        ;
      inherit (tools) bash coreutils;
      gems = packages;
      dependencyProviders.bundler = selectedBundler;
      plan =
        assert final.groups != [ ] || fail "select at least one dependency group";
        assert
          lib.all (package: package.ruby.drvPath == final.ruby.drvPath) (builtins.attrValues final.gems)
          || fail "all gems must be built for the selected Ruby";
        [
          {
            name = "ruby-bundle.assemble";
            tools = [
              final.ruby
              selectedBundler
              tools.diffutils
            ];
            run = ''
              export HOME="$TMPDIR"
              unset GEM_HOME GEM_PATH RUBYLIB BUNDLE_GEMFILE BUNDLE_PATH
              mkdir -p "$out/project"
              ${lib.optionalString (
                final.src != null
              ) ''cp -R ${final.src}/. "$out/project/"; chmod -R u+w "$out/project"''}
              cp ${final.gemfile} "$out/project/Gemfile"
              cp ${final.lockfile} "$out/project/Gemfile.lock"
              printf '%s' ${lib.escapeShellArg manifest} > bundle.json
              ${final.ruby}/bin/ruby -I ${selectedBundler}/${final.ruby.gemPath}/gems/bundler-${selectedBundler.version}/lib \
                ${./assemble.rb} bundle.json "$out"
              "$out/bin/bundle" check
              cmp ${final.lockfile} "$out/project/Gemfile.lock"
            '';
          }
        ];
      passthru = {
        inherit (final) ruby gems groups;
        bundler = selectedBundler;
        rubyDevelopment.gemDirectories = [ final.ruby.gemPath ];
        gemfile = "${placeholder "out"}/project/Gemfile";
        lockfile = "${placeholder "out"}/project/Gemfile.lock";
      };
    };
in
tvp.builder {
  inherit recipe;
  args = {
    inherit
      ruby
      bundler
      gemfile
      lockfile
      gemset
      groups
      gemConfig
      sourceOverrides
      src
      ;
  };
  argumentDefaults = { arguments, ... }: { base = arguments.ruby.specification.base; };
  dependencyNames = [
    "ruby"
    "bundler"
  ];
  metadata = {
    builder = "bundler-env.nix";
    definition = name;
    kind = "ruby-bundle";
    status.level = "ok";
  };
  selection = {
    kind = "composition";
    category = "ruby-bundle";
  };
  mkTests = _: { };
}
