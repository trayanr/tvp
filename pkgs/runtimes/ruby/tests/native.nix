# One suite, shared by every Ruby version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  package,
  tvp,
}:
let
  ruby = package;
  supportTools = with (import ../../../../bases/source-gnu { }).tools; [
    make
    grep
    sed
    gawk
    diffutils
  ];
  deps = ruby.tvp.deps // {
    inherit (ruby.runtime)
      openssl
      zlib
      libyaml
      libffi
      ;
  };
  consumerCompiler = ruby.tvp.declaredTestDependencies.consumerCompiler;
  features = ruby.passthru.tvp.features or { };
  consumerStandard = features.consumerCStandard or null;
  # Keep the independent consumer compiler, preserving all RbConfig flags.
  consumerFlags =
    pkgs.lib.optionalString (consumerStandard != null)
      ''--with-cflags="$(ruby -rrbconfig -e 'print RbConfig::CONFIG["CFLAGS"]') -std=${consumerStandard}"'';

  # 2.0.0 and older ship a tarball per patchlevel, so the version identifier
  # carries it and RUBY_VERSION does not. From 2.1 upstream ships one tarball
  # per version and the p-label is derived.
  versionParts = pkgs.lib.splitString "-p" ruby.version;
  baseVersion = builtins.head versionParts;
  patchlevel = if builtins.length versionParts > 1 then builtins.elemAt versionParts 1 else null;

  # sha256("tvp"), first 16 hex characters.
  tvpDigest = "f6f6ead0bd85c312";
in
package.testContext.mkSuite {
  inherit package;
  tools =
    package.specification.environment.tools
    ++ [ package.tvp.cc.bintools ]
    ++ (with (import ../../../../bases/source-gnu { }).tools; [
      grep
      sed
      gawk
      diffutils
    ]);
  libraries = [ package ];

  tests =
    {
      native-gem = {
        script = builtins.readFile ./native-gem.sh;
        expected = "native-gem-ok";
      };
      runtime = {
        script = ''
          mkdir home
          env -i HOME="$PWD/home" LANG=C.UTF-8 LD_DEBUG=libs ${ruby}/bin/ruby ${./fixtures/native-runtime.rb} > runtime 2> loader
          cat runtime >&2
          grep -F 'calling init: ${ruby.runtime.openssl}/lib/libssl.so.' loader >&2
          grep -F 'calling init: ${ruby.runtime.zlib}/lib/libz.so.' loader >&2
          grep -F 'calling init: ${ruby.runtime.libyaml}/lib/libyaml' loader >&2
          grep -F 'calling init: ${ruby.runtime.libffi}/lib/libffi.so.' loader >&2
          printf runtime-ok
        '';
        expected = "runtime-ok";
      };
      version = {
        script = ''
          ruby -e 'print RUBY_VERSION'
        '';
        expected = baseVersion;
      };

      smoke = {
        script = ''
          ruby ${./fixtures/smoke.rb}
        '';
        expected = "220";
      };

      stdlib = {
        script = ''
          ruby ${./fixtures/stdlib.rb}
        '';
        expected = "${tvpDigest}:6";
      };

      # runCommand is stdenvNoCC, and rbconfig records the compiler by bare name.
      compile = {
        script = ''
          mkdir -p ext && cd ext
          cp ${./fixtures/ext-extconf.rb} extconf.rb
          cp ${./fixtures/ext-tvp.c} tvp_ext.c
          # mkmf reads the installed flags but must use the independent compiler.
          ruby -rrbconfig -e '
            cc = ARGV.shift
            RbConfig::CONFIG["CC"] = cc
            RbConfig::MAKEFILE_CONFIG["CC"] = cc
            load "./extconf.rb"
          ' ${consumerCompiler}/bin/cc ${consumerFlags} > /dev/null
          grep -Fx 'CC = ${consumerCompiler}/bin/cc' Makefile >&2 || exit 1
          ${consumerCompiler}/bin/cc --version >&2
          make > /dev/null
          ruby -I. -e 'require "tvp_ext"; print TvpExt.answer'
        '';
        expected = "42";
        tools =
          assert consumerCompiler.drvPath != ruby.tvp.cc.drvPath;
          assert consumerCompiler.outPath != ruby.tvp.cc.outPath;
          assert
            pkgs.lib.versions.major consumerCompiler.version != pkgs.lib.versions.major ruby.tvp.cc.version;
          [ consumerCompiler ] ++ supportTools;
      };

      openssl = {
        script = ''
          ruby -e 'require "openssl"; print [OpenSSL::OPENSSL_VERSION.split[1], OpenSSL::Digest::SHA256.hexdigest("tvp")[0, 16]].join(" ")'
        '';
        expected = "${deps.openssl.version} ${tvpDigest}";
      };

      zlib = {
        script = ''
          ruby -e 'require "zlib"; s = "tvp" * 100; print(Zlib::Inflate.inflate(Zlib::Deflate.deflate(s)) == s ? "roundtrip-ok" : "MISMATCH")'
        '';
        expected = "roundtrip-ok";
      };

      # A missing extension library is not a build failure — Ruby drops the
      # extension and installs anyway. yaml and fiddle are the two that vanish
      # this way, so only a runtime require catches it.
      yaml = {
        script = ''
          ruby -e 'require "yaml"; print YAML.load(YAML.dump({ "tvp" => [1, 2] }))["tvp"].inject(:+)'
        '';
        expected = "3";
      };

      # Calls through libffi rather than only loading the extension.
      fiddle = {
        script = ''
          ruby -e 'require "fiddle"; print Fiddle::Function.new(Fiddle::Handle::DEFAULT["strlen"], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_SIZE_T).call("tvp")'
        '';
        expected = "3";
      };

      gems = {
        script = ''
          ruby -e 'require "rubygems"; print Gem.default_dir'
        '';
        expected = "${ruby}/${ruby.passthru.gemPath}";
      };
    }

    # Restored as guarded tests rather than removed from the fixtures: the
    # universal forms above satisfy 2.0, and these keep the coverage that
    # lowering them to the oldest common denominator would have cost everyone.
    // pkgs.lib.optionalAttrs (features.enumerableSum or false) {
      enumerable-sum = {
        script = ''
          ruby ${./fixtures/enumerable-sum.rb}
        '';
        expected = "220";
      };
    }

    // pkgs.lib.optionalAttrs (features.yamlSafeLoad or false) {
      # A different code path from YAML.load, and the one consumers should use.
      yaml-safe-load = {
        script = ''
          ruby -e 'require "yaml"; print YAML.safe_load(YAML.dump({ "tvp" => [1, 2] }))["tvp"].inject(:+)'
        '';
        expected = "3";
      };
    }

    # A patchlevel release states its own patchlevel, and only RUBY_PATCHLEVEL
    # carries it — RUBY_VERSION does not.
    // pkgs.lib.optionalAttrs (patchlevel != null) {
      patchlevel = {
        script = ''
          ruby -e 'print RUBY_PATCHLEVEL'
        '';
        expected = patchlevel;
      };
    }

    # Upstream retired ext/gdbm at 3.1 and ext/readline at 3.3. The builder for
    # those lines drops the argument, so the declared graph selects the test.
    // pkgs.lib.optionalAttrs (deps ? gdbm) {
      # Two processes, so the value is proven to have been written.
      gdbm = {
        script = ''
          ruby -e 'require "gdbm"; GDBM.open("tvp.db") { |db| db["k"] = "v" }'
          ruby -e 'require "gdbm"; GDBM.open("tvp.db") { |db| print db["k"] }'
        '';
        expected = "v";
      };
    }

    // pkgs.lib.optionalAttrs (deps ? readline) {
      readline = {
        script = ''
          ruby -e 'require "readline"; print Readline.respond_to?(:readline) ? "readline-ok" : "MISSING"'
        '';
        expected = "readline-ok";
      };
    }

    # Upstream turns these on whenever the toolchain allows, so a build that
    # quietly lost the toolchain still installs and still passes every other
    # test. Read from the declared graph, not from a version comparison.
    // pkgs.lib.optionalAttrs (ruby.passthru.tvp.jit.yjit or false) {
      yjit-functional = {
        script = ''
          ruby --yjit --yjit-call-threshold=1 -e 'def answer(x); x * 2; end; 1000.times { abort unless answer(21) == 42 }; abort unless RubyVM::YJIT.enabled? && RubyVM::YJIT.runtime_stats[:compiled_iseq_count] > 0; print "compiled"'
        '';
        expected = "compiled";
      };
      yjit = {
        script = ''
          ruby --yjit -e 'print RubyVM::YJIT.enabled?'
        '';
        expected = "true";
      };
    }

    // pkgs.lib.optionalAttrs (ruby.passthru.tvp.jit.zjit or false) {
      zjit = {
        script = ''
          ruby --zjit -e 'print RubyVM::ZJIT.enabled?'
        '';
        expected = "true";
      };
    }

    # ldd is glibc's; Darwin needs otool -L, as a separate test.
    // pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      # Proves the declared OpenSSL is what is linked, not merely one reporting
      # the same version.
      openssl-linkage = {
        script = ''
          so=$(ruby -e 'require "openssl"; print $LOADED_FEATURES.grep(/openssl\.so$/).first')
          LD_DEBUG=libs ruby -e 'require "openssl"' 2> loader
          grep -F 'calling init: ${deps.openssl.out}/lib/libssl' loader >&2
          printf linked
        '';
        expected = "linked";

      };
    }

    // pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && deps ? libyaml) {
      # yaml and fiddle prove the extension loaded, never which library it
      # loaded — both resolve against whatever the loader reaches first.
      yaml-linkage = {
        script = ''
          so=$(ruby -e 'require "yaml"; print $LOADED_FEATURES.grep(/psych\.so$/).first')
          LD_DEBUG=libs ruby -e 'require "yaml"' 2> loader
          grep -F 'calling init: ${deps.libyaml.out}/lib/libyaml' loader >&2
          printf linked
        '';
        expected = "linked";

      };
    }

    // pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.isLinux && deps ? libffi) {
      fiddle-linkage = {
        script = ''
          so=$(ruby -e 'require "fiddle"; print $LOADED_FEATURES.grep(/fiddle\.so$/).first')
          LD_DEBUG=libs ruby -e 'require "fiddle"' 2> loader
          grep -F 'calling init: ${deps.libffi.out}/lib/libffi' loader >&2
          printf linked
        '';
        expected = "linked";

      };
    };
}
