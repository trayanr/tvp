# Public, synthetic installed-result checks for the external Ruby helper API.
{ tvp }:
let
  makeChecks =
    name: ruby: bundler:
    let
      base = ruby.specification.base;
      context = ruby.testContext;
      archive =
        directory: platform:
        tvp.builder {
          recipe =
            {
              ruby,
              source,
              platform,
            }:
            {
              pname = "ruby-gem-source-${directory}-${platform}";
              version = "1";
              src = null;
              inherit base;
              bash = base.shell;
              coreutils = base.coreutils;
              plan = [
                (
                  (base.environment { tools = [ ruby ]; })
                  // {
                    name = "fixture.archive";
                    run = ''
                      export HOME="$TMPDIR/home"
                      mkdir -p "$HOME" "$out"
                      cp -R ${source}/. .
                      chmod -R u+w .
                      ${ruby}/bin/ruby -e '
                        spec = Gem::Specification.load(ARGV[0])
                        spec.platform = ARGV[1]
                        File.write("fixture.gemspec", spec.to_ruby)
                      ' tvp-${directory}.gemspec ${platform}
                      ${ruby}/bin/gem build fixture.gemspec >&2
                      cp tvp-${directory}-1.0.0${if platform == "ruby" then "" else "-${platform}"}.gem "$out/"
                    '';
                  }
                )
              ];
            };
          args = {
            inherit ruby platform;
            source = ./fixtures + "/${directory}";
          };
          dependencyNames = [ "ruby" ];
          metadata.kind = "fixture";
          selection.kind = "fixture";
          mkTests = _: { };
        };
      archives = builtins.listToAttrs (
        map
          (directory: {
            name = "tvp-${directory}";
            value = "${archive directory "ruby"}/tvp-${directory}-1.0.0.gem";
          })
          [
            "pure"
            "native"
            "test"
          ]
      );
      nativeSourceArchive = tvp.builder {
        recipe = { }: {
          pname = "ruby-native-source-archive";
          version = "1";
          src = null;
          inherit base;
          bash = base.shell;
          coreutils = base.coreutils;
          plan = [
            (
              (base.environment {
                tools = [
                  base.tools.gnutar
                  base.tools.gzip
                ];
              })
              // {
                name = "fixture.source-archive";
                run = ''
                  mkdir -p "$out" source/tvp-native-1.0.0
                  cp -R ${./fixtures/native}/. source/tvp-native-1.0.0/
                  tar -czf "$out/source.tar.gz" -C source tvp-native-1.0.0
                '';
              }
            )
          ];
        };
        args = { };
        dependencyNames = [ ];
        metadata.kind = "fixture";
        selection.kind = "fixture";
        mkTests = _: { };
      };
      pure = tvp.lib.ruby.buildGem {
        inherit tvp ruby;
        name = "tvp-pure";
        version = "1.0.0";
        src = archives.tvp-pure;
      };
      platformArchive = "${archive "pure" "x86_64-linux"}/tvp-pure-1.0.0-x86_64-linux.gem";
      foreignPlatformArchive = "${archive "pure" "x86_64-darwin"}/tvp-pure-1.0.0-x86_64-darwin.gem";
      platformPure = tvp.lib.ruby.buildGem {
        inherit tvp ruby;
        name = "tvp-pure";
        version = "1.0.0";
        platform = "x86_64-linux";
        src = platformArchive;
      };
      native = tvp.lib.ruby.buildGem {
        inherit tvp ruby;
        name = "tvp-native";
        version = "1.0.0";
        src = if name == "modern" then "${nativeSourceArchive}/source.tar.gz" else ./fixtures/native;
        sourceType = "source";
      };
      support = tvp.lib.ruby.buildGem {
        inherit tvp ruby;
        name = "tvp-support";
        version = "1.0.0";
        src = ./fixtures/support;
        sourceType = "source";
        dependencies = [ pure ];
      };
      transitive = tvp.lib.ruby.buildGem {
        inherit tvp ruby;
        name = "tvp-transitive";
        version = "1.0.0";
        src = ./fixtures/transitive-native;
        sourceType = "source";
        dependencies = [ support ];
      };
      gemset = builtins.mapAttrs (name: _: {
        version = "1.0.0";
        groups = if name == "tvp-test" then [ "test" ] else [ "default" ];
        platforms = [ ];
        source = {
          type = "gem";
          remotes = [ "https://invalid.example" ];
          sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
        };
      }) archives;
      lockfile = builtins.toFile "Gemfile-${name}.lock" ''
        GEM
          remote: https://invalid.example/
          specs:
            tvp-native (1.0.0)
            tvp-pure (1.0.0)
            tvp-test (1.0.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          tvp-native (= 1.0.0)
          tvp-pure (= 1.0.0)
          tvp-test (= 1.0.0)

        BUNDLED WITH
           ${bundler.version}
      '';
      bundleArgs = {
        inherit
          tvp
          ruby
          bundler
          gemset
          lockfile
          ;
        name = "synthetic-${name}";
        gemfile = ./fixtures/Gemfile;
        sourceOverrides = archives;
      };
      bundle = tvp.lib.ruby.bundlerEnv bundleArgs;
      mixedRuby = tvp.lib.ruby.bundlerEnv (
        bundleArgs
        // {
          gemConfig.tvp-native.ruby =
            if name == "legacy" then tvp.canonical.ruby_3_3_12 else tvp.canonical.ruby_2_7_0;
        }
      );
      missingDependency = tvp.lib.ruby.bundlerEnv (
        bundleArgs
        // {
          gemset = gemset // {
            tvp-pure = gemset.tvp-pure // {
              dependencies = [ "tvp-missing" ];
            };
          };
        }
      );
      testBundle = tvp.lib.ruby.bundlerEnv (
        bundleArgs
        // {
          groups = [
            "default"
            "test"
          ];
        }
      );
      sourceBundle = tvp.lib.ruby.bundlerEnv {
        inherit tvp ruby bundler;
        name = "synthetic-sources-${name}";
        src = ./fixtures;
        gemfile = builtins.toFile "Gemfile-sources-${name}" ''
          asset = File.expand_path('git/dist/widget.js', __dir__)
          raise 'Missing application source asset' unless File.read(asset).include?('42')
          source 'https://invalid.example'
          gem 'tvp-pure', '= 1.0.0', :git => 'https://invalid.example/tvp-pure.git', :ref => '0123456789abcdef0123456789abcdef01234567'
          gem 'tvp-test', '= 1.0.0', :git => 'https://invalid.example/tvp-pure.git', :ref => '0123456789abcdef0123456789abcdef01234567'
          gem 'tvp-native', '= 1.0.0', :path => 'native'
        '';
        lockfile = builtins.toFile "Gemfile-sources-${name}.lock" ''
          GIT
            remote: https://invalid.example/tvp-pure.git
            revision: 0123456789abcdef0123456789abcdef01234567
            ref: 0123456789abcdef0123456789abcdef01234567
            specs:
              tvp-pure (1.0.0)
              tvp-test (1.0.0)

          PATH
            remote: native
            specs:
              tvp-native (1.0.0)

          GEM
            remote: https://invalid.example/
            specs:

          PLATFORMS
            ruby

          DEPENDENCIES
            tvp-native (= 1.0.0)!
            tvp-pure (= 1.0.0)!
            tvp-test (= 1.0.0)!

          BUNDLED WITH
             ${bundler.version}
        '';
        gemset = {
          tvp-test = {
            version = "1.0.0";
            groups = [ "default" ];
            source.type = "git";
          };
          tvp-pure = {
            version = "1.0.0";
            groups = [ "default" ];
            platforms = [ ];
            source = {
              type = "git";
              url = "https://invalid.example/tvp-pure.git";
              rev = "0123456789abcdef0123456789abcdef01234567";
            };
          };
          tvp-native = {
            version = "1.0.0";
            groups = [ "default" ];
            platforms = [ ];
            source = {
              type = "path";
              path = "native";
            };
          };
        };
        sourceOverrides = {
          tvp-test = ./fixtures/git;
          tvp-pure = ./fixtures/git;
          tvp-native = ./fixtures/native;
        };
      };
    in
    {
      "ruby-gem-definitions-${name}" = import ./definitions.nix {
        inherit
          tvp
          ruby
          bundler
          name
          ;
      };
      "ruby-application-${name}" = import ./application.nix { inherit tvp bundle name; };
      "ruby-gem-${name}" = context.mkTest {
        package = pure;
        name = "require";
        tools = [
          ruby
          base.tools.grep
        ];
        script = ''
          export GEM_HOME=${pure}/${ruby.gemPath}
          export GEM_PATH="$GEM_HOME:${ruby}/${ruby.gemPath}"
          ${ruby}/bin/ruby -rtvp_pure -e 'abort unless TvpPure::ANSWER == 42; print "gem-ok"'
          export GEM_HOME=${platformPure}/${ruby.gemPath}
          export GEM_PATH="$GEM_HOME:${ruby}/${ruby.gemPath}"
          ${ruby}/bin/ruby -rtvp_pure -e '
            abort unless TvpPure::ANSWER == 42
            abort unless Gem.loaded_specs.fetch("tvp-pure").platform.to_s == "x86_64-linux"
          '
          if ${ruby}/bin/ruby ${../gem-source.rb} verify ${platformArchive} tvp-pure 1.0.0 ruby > platform-error.log 2>&1; then
            echo "Undeclared platform gem was accepted" >&2
            exit 1
          fi
          grep -F 'expected platform ruby, found x86_64-linux' platform-error.log >&2
          if ${ruby}/bin/ruby ${../gem-source.rb} verify ${foreignPlatformArchive} tvp-pure 1.0.0 x86_64-darwin > host-error.log 2>&1; then
            echo "Incompatible platform gem was accepted" >&2
            exit 1
          fi
          grep -F 'platform x86_64-darwin is incompatible with this Ruby' host-error.log >&2

          mkdir incompatible-gems
          cp -R ${./fixtures/pure}/. incompatible-gems/
          cd incompatible-gems
          ${ruby}/bin/ruby -rrubygems/package -e '
            {"ruby" => :required_ruby_version=, "rubygems" => :required_rubygems_version=}.each do |kind, setter|
              spec = Gem::Specification.load("tvp-pure.gemspec").dup
              spec.public_send(setter, ">= 99")
              Gem::Package.build(spec, false, false, "incompatible-#{kind}.gem")
            end
          ' >&2
          reject_incompatible() {
            if ${ruby}/bin/ruby ${../gem-source.rb} verify "$1" tvp-pure 1.0.0 ruby > version-error.log 2>&1; then
              echo "Incompatible gem $1 was accepted" >&2
              exit 1
            fi
            grep -F "$2" version-error.log >&2
          }
          reject_incompatible incompatible-ruby.gem 'requires Ruby >= 99'
          reject_incompatible incompatible-rubygems.gem 'requires RubyGems >= 99'
        '';
        expected = "gem-ok";
      };
      "ruby-native-gem-${name}" = context.mkTest {
        package = native;
        name = "load";
        tools = [
          ruby
          base.tools.patchelf
        ];
        script = ''
          export GEM_HOME=${native}/${ruby.gemPath}
          export GEM_PATH="$GEM_HOME:${ruby}/${ruby.gemPath}"
          ${ruby}/bin/ruby -rtvp_native -e 'abort unless TvpNative.answer == 42; print "native-ok"'
          ${ruby}/bin/ruby -e '
            expected = [File.read(ARGV[0]).strip].pack("H*")
            abort "Foreign ELF payload changed" unless File.binread(ARGV[1]) == expected
          ' ${./fixtures/native/payload/foreign-elf32.hex} ${native}/${ruby.gemPath}/gems/tvp-native-1.0.0/payload/foreign-elf32
          helper=${native}/${ruby.gemPath}/gems/tvp-native-1.0.0/payload/native-helper
          test "$(${base.tools.patchelf}/bin/patchelf --print-interpreter "$helper")" = '${base.compiler.libc}/${base.platform.dynamicLinker}'
          test "$("$helper")" = host-helper-ok
          export GEM_HOME=${transitive}/${ruby.gemPath}
          export GEM_PATH="$GEM_HOME:${support}/${ruby.gemPath}:${pure}/${ruby.gemPath}:${ruby}/${ruby.gemPath}"
          ${ruby}/bin/ruby -rtvp_transitive -e 'abort "Transitive native build failed" unless TvpTransitive.answer == 42'
        '';
        expected = "native-ok";
      };
      "ruby-bundle-${name}" =
        assert !(builtins.tryEval missingDependency.drvPath).success;
        assert !(builtins.tryEval mixedRuby.drvPath).success;
        context.mkTest {
          package = bundle;
          name = "locked";
          tools = [ base.tools.diffutils ];
          script = ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            unset GEM_PATH GEM_HOME RUBYLIB BUNDLE_GEMFILE BUNDLE_PATH
            lock_path=$(${bundle}/bin/bundle exec ruby -e 'print Bundler.default_lockfile')
            cmp ${lockfile} "$lock_path"
            ${bundle}/bin/bundle --version >&2
            ${bundle}/bin/bundle check >&2
            ${bundle}/bin/bundle exec ruby -rtvp_pure -rtvp_native -e '
              abort "Wrong Ruby #{RUBY_VERSION}" unless RUBY_VERSION == ARGV[0]
              abort "Wrong Bundler #{Bundler::VERSION}" unless Bundler::VERSION == ARGV[1]
              abort "Wrong gem results" unless TvpPure::ANSWER == 42 && TvpNative.answer == 42
              abort "Excluded test gem activated" if Gem.loaded_specs.key?("tvp-test")
              print "bundle-ok"
            ' ${ruby.version} ${bundler.version}
            test "$(${bundle}/bin/bundle exec tvp-answer)" = 42
            test "$(${bundle}/bin/tvp-answer)" = 42
            cmp ${lockfile} "$lock_path"
            ${testBundle}/bin/bundle exec ruby -rtvp_test -e 'abort unless TvpTest::ANSWER == 43'
          '';
          expected = "bundle-ok";
        };
      "ruby-bundle-sources-${name}" = context.mkTest {
        package = sourceBundle;
        name = "sources";
        script = ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          unset GEM_PATH GEM_HOME RUBYLIB BUNDLE_GEMFILE BUNDLE_PATH
          ${sourceBundle}/bin/bundle check >&2
          ${sourceBundle}/bin/bundle exec ruby -rtvp_pure -rtvp_native -rtvp_test -e '
            abort unless TvpPure::ANSWER == 42 && TvpNative.answer == 42 && TvpTest::ANSWER == 43
            directory = Gem.loaded_specs.fetch("tvp-pure").full_gem_path
            abort "Git gem omitted source files" unless File.file?(File.join(directory, "lib", "tvp_pure.rb"))
            abort "Git gem omitted tracked assets" unless File.read(File.join(directory, "dist", "widget.js")).include?("42")
            {
              "bare.js" => "./target.js",
              "dot.js" => "./target.js",
              "parent.js" => "../shared.js"
            }.each do |link, target|
              path = File.join(directory, "assets", "nested", link)
              abort "Git source symlink changed meaning" unless File.symlink?(path) && File.readlink(path) == target && File.read(path).include?("42")
            end
            original = File.join(ARGV.fetch(0), "assets", "nested", "bare.js")
            abort "Original source symlink was modified" unless File.readlink(original) == "target.js"
            abort "Git metadata was packaged" if File.exist?(File.join(directory, ".git"))
            local = Gem.loaded_specs.fetch("tvp-native").full_gem_path
            abort "Local source was not overlaid with the packaged gem" unless File.binread(File.join(local, "payload", "foreign-elf32")).start_with?("\x7fELF")
            asset = Bundler.default_gemfile.dirname.join("git", "dist", "widget.js")
            abort "Application source asset was not preserved" unless asset.read.include?("42")
            print "sources-ok"
          ' ${./fixtures/git}
        '';
        expected = "sources-ok";
      };
    };
in
(makeChecks "legacy" tvp.canonical.ruby_2_7_0 tvp.canonical.bundler_1_17_3)
// (makeChecks "modern" tvp.canonical.ruby_3_3_12 tvp.canonical.bundler_2_5_20)
