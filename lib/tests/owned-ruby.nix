{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps;
  p = tvp.canonical.ruby_4_0_6;
  pilot = tvp.variants.build-steps.ruby_4_0_6;
  compatibleZlib = tvp.packages.zlib_1_3_1;
  runtime = p.editRuntime (r: r // { zlib = compatibleZlib; });
  off = p.override {
    yjit = false;
    zjit = false;
    rustc = throw "disabled Rust forced";
  };
  noYjit = p.override { yjit = false; };
  noZjit = p.override { zjit = false; };
  insert = steps.insertAfter "ruby.build" [
    {
      name = "fixture.ordered";
      run = ":";
    }
  ];
  edited = (p.editSteps insert).editRuntime (r: r);
  disabled = (p.override { doCheck = false; }).editSteps (
    steps.replace "ruby.check" (_: {
      name = "ruby.check";
      enabled = false;
      tools = throw "disabled tools";
      libraries = throw "disabled libraries";
      run = throw "disabled run";
    })
  );
  tagged =
    (tvp.lib.packages.withConstraint { reason = "Ruby contract fixture."; } tvp.packages.ruby_4)
    .editRuntime
      (r: r);
  gem = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        ruby,
        version,
        src,
      }:
      {
        pname = "owned-ruby-gem-fixture";
        inherit
          base
          bash
          coreutils
          version
          src
          ;
        plan = [
          (
            (base.environment { tools = [ ruby ]; })
            // {
              name = "gem.install";
              run = ''
                mkdir lib
                printf 'module TvpGem; ANSWER = 42; end\n' > lib/tvp_gem.rb
                cat > tvp-owned.gemspec <<'SPEC'
                Gem::Specification.new do |s|
                  s.name = 'tvp-owned'
                  s.version = '1.0.0'
                  s.summary = 'Owned discovery fixture'
                  s.authors = ['TVP']
                  s.files = ['lib/tvp_gem.rb']
                end
                SPEC
                ${ruby}/bin/gem build tvp-owned.gemspec
                ${ruby}/bin/gem install --local --no-document --install-dir "$out/gems" tvp-owned-1.0.0.gem
                mkdir -p "$out/site"
                printf 'module TvpSite; ANSWER = 43; end\n' > "$out/site/tvp_site.rb"
                # This hook must remain inert during owned discovery.
                mkdir "$out/nix-support"
                printf 'exit 99\n' > "$out/nix-support/setup-hook"
              '';
            }
          )
        ];
        passthru.rubyDevelopment = {
          gemDirectories = [ "gems" ];
          siteDirectories = [ "site" ];
        };
      };
    args = {
      base = tvp.bases.default;
      inherit (tvp.packages) bash coreutils;
      ruby = p;
      version = "1";
      src = null;
    };
    dependencyNames = [ "ruby" ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  # Owned packages expose passthru explicitly; the Ruby provider reads its own
  # narrow metadata, never a generic propagated build graph.
  gemInput = gem // {
    inherit (gem.passthru) rubyDevelopment;
  };
  consumer = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
        ruby,
        pkgConfig,
        make,
        gemInput,
        version,
        src,
      }:
      let
        env = base.environment {
          tools = [
            ruby
            pkgConfig
            make
          ];
          libraries = [ ruby ];
        };
        gemEnv = base.environment {
          tools = [ ruby ];
          libraries = [
            gemInput
            gemInput
          ];
        };
      in
      {
        pname = "owned-ruby-consumer";
        inherit
          base
          bash
          coreutils
          version
          src
          ;
        plan = [
          (
            env
            // {
              name = "consumer.extension";
              run = ''
                test "$($PKG_CONFIG --modversion ruby-4.0)" = 4.0.6
                # The compiler interface alone must contribute BOTH header directories.
                "$CC" -shared -fPIC ${../../pkgs/runtimes/ruby/tests/fixtures/ext-tvp.c} -lruby -o tvp_ext.so
                env -i HOME="$TMPDIR" ${ruby}/bin/ruby -I. -e 'require "tvp_ext"; abort unless TvpExt.answer == 42'
                "$CC" -shared -fPIC $($PKG_CONFIG --cflags ruby-4.0) ${../../pkgs/runtimes/ruby/tests/fixtures/ext-tvp.c} $($PKG_CONFIG --libs ruby-4.0) -o tvp_ext.so
                env -i HOME="$TMPDIR" ${ruby}/bin/ruby -I. -e 'require "tvp_ext"; abort unless TvpExt.answer == 42'
                cp ${../../pkgs/runtimes/ruby/tests/fixtures/ext-tvp.c} tvp_ext.c
                cp ${../../pkgs/runtimes/ruby/tests/fixtures/ext-extconf.rb} extconf.rb
                ${ruby}/bin/ruby extconf.rb
                ${make}/bin/make clean all
                env -i HOME="$TMPDIR" ${ruby}/bin/ruby -I. -e 'require "tvp_ext"; abort unless TvpExt.answer == 42'
                mkdir "$out"
                cp Makefile tvp_ext.so "$out/"
              '';
            }
          )
          (
            gemEnv
            // {
              name = "consumer.gem-provider";
              run = ''
                test "$GEM_PATH" = '${gemInput}/gems:${ruby}/${ruby.gemPath}'
                test "$RUBYLIB" = '${gemInput}/site'
                env -i HOME="$TMPDIR" XDG_CONFIG_HOME="$TMPDIR/config" GEM_PATH="$GEM_PATH" RUBYLIB="$RUBYLIB" ${ruby}/bin/ruby -rtvp_gem -rtvp_site -e 'abort unless TvpGem::ANSWER == 42 && TvpSite::ANSWER == 43; abort unless Gem.loaded_specs["tvp-owned"].full_gem_path.start_with?(ARGV[0])' ${gemInput}
                printf '%s\n' "$GEM_PATH" "$RUBYLIB" > "$out/discovery"
              '';
            }
          )
          {
            name = "consumer.clean-runtime";
            run = ''
              mkdir -p "$TMPDIR/home" "$TMPDIR/config" "$TMPDIR/cache"
              ${coreutils}/bin/env -i HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_CACHE_HOME="$TMPDIR/cache" LANG=C.UTF-8 LD_DEBUG=libs ${ruby}/bin/ruby ${../../pkgs/runtimes/ruby/tests/fixtures/owned-runtime.rb} > "$out/runtime" 2> "$out/loader"
              grep -F 'calling init: ${ruby.runtime.zlib}/lib/libz.so.1' "$out/loader"
              grep -F 'calling init: ${ruby.runtime.openssl}/lib/libssl.so.' "$out/loader"
              grep -F 'calling init: ${ruby.runtime.libyaml}/lib/libyaml' "$out/loader"
              grep -F 'calling init: ${ruby.runtime.libffi}/lib/libffi.so.' "$out/loader"
              ${lib.optionalString (ruby.drvPath != p.drvPath) ''
                if grep -F 'calling init: ${p.tvp.deps.zlib}/lib/' "$out/loader"; then exit 1; fi
              ''}
            '';
          }
        ];
      };
    args = {
      base = tvp.bases.default;
      inherit (tvp.packages) bash coreutils;
      ruby = p;
      pkgConfig = tvp.packages.pkg-config;
      make = tvp.packages.gnumake;
      inherit gemInput;
      version = "1";
      src = null;
    };
    dependencyNames = [
      "ruby"
      "pkgConfig"
      "make"
      "gemInput"
    ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  runtimeConsumer = consumer.override { ruby = runtime; };
  traceTool =
    name: binary: original:
    tvp.bases.default.stdenv.mkDerivation {
      name = "ruby-selected-${name}";
      buildCommand = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/${binary}" <<'SCRIPT'
        #!${tvp.packages.bash}/bin/bash
        printf '%s\n' '${name}' >> "$NIX_BUILD_TOP/selected-tools"
        exec ${original}/bin/${binary} "$@"
        SCRIPT
        chmod +x "$out/bin/${binary}"
      '';
    };
  selected =
    (p.override {
      gnumake = traceTool "make" "make" p.tvp.deps.gnumake;
      gnused = traceTool "sed" "sed" p.tvp.deps.gnused;
      python = traceTool "python" "python3" p.tvp.deps.python;
    }).editSteps
      (
        steps.append [
          {
            name = "fixture.selected-tools";
            run = ''
              for tool in make sed python; do grep -Fx "$tool" "$NIX_BUILD_TOP/selected-tools"; done
              sort -u "$NIX_BUILD_TOP/selected-tools" > "$out/selected-tools"
            '';
          }
        ]
      );
  supportInputs = {
    ruby = p;
    inherit compatibleZlib;
    inherit (tvp.packages) bash coreutils;
    make = tvp.packages.gnumake;
    pkgConfig = tvp.packages.pkg-config;
    python = p.tvp.deps.python;
    sed = p.tvp.deps.gnused;
    environment = tvp.bases.default.stdenv;
    compiler = tvp.bases.default.stdenv.cc;
  };
  supportRows = builtins.filter (
    row: row.scope == "build-test-support" && row.consumer == "owned-ruby"
  ) tvp.dependencyInventory.support;
  env = p.specification.base.environment {
    tools = [ p ];
    libraries = [
      gemInput
      gemInput
    ];
  };
  inactive = p.specification.base.environment { libraries = [ gemInput ]; };
  contracts = {
    inventorySupport =
      builtins.length supportRows == builtins.length (builtins.attrNames supportInputs)
      && builtins.all (
        r:
        r.resolved.drv == supportInputs.${r.dependency}.drvPath
        && r.resolved.out == supportInputs.${r.dependency}.outPath
      ) supportRows;
    sameRecipe = p.drvPath == pilot.drvPath;
    zeroSplit = !(steps.partition p.buildSteps).split && !(p ? artifact);
    runtimeRebuilds = p.drvPath != runtime.drvPath && !(runtime ? artifact);
    runtimeSummaryGuard =
      !(builtins.tryEval (p.editRuntime (r: r // { libraries = [ ]; })).drvPath).success;
    runtimeSummaryFollowsProviders =
      map toString runtime.runtime.libraries == map toString [
        runtime.runtime.openssl
        compatibleZlib
        runtime.runtime.libyaml
        runtime.runtime.libffi
      ];
    compileInputsPreserved = p.specification.environment == runtime.specification.environment;
    operativeRuntime = lib.hasInfix (builtins.unsafeDiscardStringContext (toString compatibleZlib)) (
      lib.concatStrings (map (s: s.run) (lib.filter (s: s.name == "ruby.lookup.zlib") runtime.buildSteps))
    );
    lazyRust =
      builtins.isString off.drvPath
      && !(off.tvp.deps ? rustc)
      && !(off.tvp.declaredDependencies ? rustc)
      && !(off.tests ? yjit)
      && !(off.tests ? zjit);
    bothIndependent =
      !(p.override { yjit = false; }).tvp.jit.yjit
      && (p.override { yjit = false; }).tvp.jit.zjit
      && (p.override { zjit = false; }).tvp.jit.yjit
      && !(p.override { zjit = false; }).tvp.jit.zjit;
    disabledLazy =
      builtins.isString disabled.drvPath
      && !(lib.any (s: s.name == "ruby.check") (steps.active disabled.buildSteps));
    orderedReplay =
      (edited.override { doCheck = false; }).drvPath
      == (((p.override { doCheck = false; }).editSteps insert).editRuntime (r: r)).drvPath;
    currentArguments =
      (disabled.override (a: {
        doCheck = a.doCheck;
      })).drvPath == disabled.drvPath;
    source = p.src.drvPath == pilot.src.drvPath;
    noOp = (p.override { }).drvPath == p.drvPath && (p.editSteps (s: s)).drvPath == p.drvPath;
    noOverrideAttrs = !(p ? overrideAttrs);
    noSetup =
      !lib.hasInfix (builtins.unsafeDiscardStringContext "source ${p.stdenv}/setup") (
        lib.concatStrings p.buildStepRunner.childScripts
      );
    unknownRejected = !(builtins.tryEval (p.override { unknown = true; }).drvPath).success;
    environmentRebound =
      let
        q = p.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides = s.environment.overrides // {
                values = s.environment.overrides.values // {
                  RUBY_OWNED_PROBE = "selected";
                };
              };
            };
          }
        );
      in
      q.drvPath != p.drvPath
      &&
        (builtins.head (lib.filter (s: s.name == "ruby.configure") q.buildSteps)).env.RUBY_OWNED_PROBE
        == "selected";
    providerEdited =
      let
        q = p.edit (
          s:
          s
          // {
            buildEnvironment = args: (s.buildEnvironment args) // { values.RUBY_OWNED_PROVIDER = "selected"; };
          }
        );
        e = q.specification.base.environment { tools = [ q ]; };
      in
      q.drvPath == p.drvPath && e.env.RUBY_OWNED_PROVIDER == "selected";
    environmentEdit =
      (p.edit (
        s:
        s
        // {
          environment = s.environment // {
            tools = s.environment.tools;
          };
        }
      )).drvPath == p.drvPath;
    orderedSpec =
      ((p.edit (s: s // { meta.description = "first"; })).edit (
        s: s // { meta.description = s.meta.description + " second"; }
      )).meta.description == "first second";
    publicRequirements =
      p.development.libraries == [ ] && builtins.length p.development.includeDirectories == 2;
    providerActivation =
      !(inactive.env ? GEM_PATH)
      && env.env.GEM_PATH == "${gemInput}/gems:${p}/${p.gemPath}"
      && env.env.RUBYLIB == "${gemInput}/site";
    testsRebound =
      runtime.tests.gems.package.outPath == runtime.outPath
      && runtime.tests.gems.drvPath != p.tests.gems.drvPath;
    projections =
      lib.all
        (
          q:
          q.tests.gems.drvPath == runtime.tests.gems.drvPath
          && q.tvp.deps.zlib.drvPath == p.tvp.deps.zlib.drvPath
        )
        (
          [
            runtime
            runtime.out
          ]
          ++ runtime.all
        );
    tags =
      lib.all
        (q: q.__tvpSelection.selector == "ruby_4" && q.__tvpSelection.reason == "Ruby contract fixture.")
        (
          [
            tagged
            tagged.out
          ]
          ++ tagged.all
        );
    legacy = tvp.canonical.ruby_4_0_5 ? overrideAttrs && !(tvp.canonical.ruby_4_0_5 ? edit);
  };
  failed = lib.filter (n: !contracts.${n}) (lib.attrNames contracts);
in
assert failed == [ ] || throw "Owned Ruby contracts: ${lib.concatStringsSep ", " failed}";
(tvp.bases.default.stdenv.mkDerivation {
  name = "tvp-owned-ruby-contracts";
  buildCommand = ''
    test -e ${consumer}/discovery
    test -e ${runtimeConsumer}/discovery
    test -x ${disabled}/bin/ruby
    test -e ${selected}/selected-tools
    ${off}/bin/ruby -e 'abort if (defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?) || (defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)'
    ${noYjit}/bin/ruby --zjit -e 'abort if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?; abort unless RubyVM::ZJIT.enabled?'
    ${noZjit}/bin/ruby --yjit -e 'abort unless RubyVM::YJIT.enabled?; abort if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?'

    printf '%s\n' '${builtins.toJSON contracts}' > "$out"
  '';
})
// {
  passthru = {
    inherit
      contracts
      consumer
      runtime
      runtimeConsumer
      disabled
      selected
      off
      gem
      noYjit
      noZjit
      ;
  };
}
