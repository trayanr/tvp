# Extra current-profile assertions; universal bodies remain in default.nix.
{
  package,
  lib,
  context,
}:
let
  ruby = package;
  deps = ruby.tvp.deps;
  native4 = ruby.specification.installedInterface.nativeLine == "4";
  tvpDigest = "f6f6ead0bd85c312";
  tools = ruby.specification.base.standardTools;
in
(context.mkSuite {
  inherit package;
  tools =
    package.specification.environment.tools
    ++ [ package.tvp.cc.bintools ]
    ++ [
      tools.gnumake
      tools.grep
      tools.sed
      tools.gawk
      tools.diffutils
    ];
  libraries = [ package ];
  tests =
    {
      native-gem =
        if native4 then
          {
            script =
              ''
                  test -z "$(find ${ruby}/${ruby.gemPath} -name mkmf.log -print -quit)"
                ruby -rrbconfig -e 'abort unless RbConfig::CONFIG["EGREP"] == "grep -E"'
              ''
              + builtins.readFile ./native-gem.sh;
            expected = "native-gem-ok";
          }
        else
          {
            script = builtins.readFile ./native-gem.sh;
            expected = "native-gem-ok";
          };
      runtime =
        if native4 then
          {
            script = ''
              mkdir home
              env -i HOME="$PWD/home" LANG=C.UTF-8 LD_DEBUG=libs ${ruby}/bin/ruby ${./fixtures/native-runtime-4.rb} > runtime 2> loader
              cat runtime >&2
              grep -F 'calling init: ${ruby.runtime.openssl}/lib/libssl.so.' loader >&2
              grep -F 'calling init: ${ruby.runtime.zlib}/lib/libz.so.' loader >&2
              grep -F 'calling init: ${ruby.runtime.libyaml}/lib/libyaml' loader >&2
              grep -F 'calling init: ${ruby.runtime.libffi}/lib/libffi.so.' loader >&2
              printf runtime-ok
            '';
            expected = "runtime-ok";
          }
        else
          {
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
    // lib.optionalAttrs (deps ? libyaml) {
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
    // lib.optionalAttrs (deps ? libffi) {
      fiddle-linkage = {
        script = ''
          so=$(ruby -e 'require "fiddle"; print $LOADED_FEATURES.grep(/fiddle\.so$/).first')
          LD_DEBUG=libs ruby -e 'require "fiddle"' 2> loader
          grep -F 'calling init: ${deps.libffi.out}/lib/libffi' loader >&2
          printf linked
        '';
        expected = "linked";

      };
    }
    // lib.optionalAttrs native4 {
      runtime-expectation = {
        script = ''
          LD_DEBUG=libs ruby -ropenssl -rzlib -ryaml -rfiddle -e 'puts "loaded"' > loaded 2> loader
          grep -Fx loaded loaded >&2
          ${lib.concatMapStringsSep "\n" (
            p: "grep -F 'calling init: ${p}/lib/' loader >&2"
          ) ruby.runtime.libraries}
          printf reachable
        '';
        expected = "reachable";
      };
      openssl = {
        script = ''
          ruby -e 'require "openssl"; print [OpenSSL::OPENSSL_VERSION.split[1], OpenSSL::OPENSSL_LIBRARY_VERSION.split[1], OpenSSL::Digest::SHA256.hexdigest("tvp")[0, 16]].join(" ")'
        '';
        expected = "${ruby.specification.libraries.openssl.version} ${ruby.runtime.openssl.version} ${tvpDigest}";
      };
    }
    // lib.optionalAttrs (native4 && (ruby.tvp.jit.yjit or false)) {
      yjit-functional = {
        script = ''
          ruby --yjit --yjit-call-threshold=1 -e 'def answer(x); x * 2; end; 1000.times { abort unless answer(21) == 42 }; abort unless RubyVM::YJIT.enabled? && RubyVM::YJIT.runtime_stats[:compiled_iseq_count] > 0; print "compiled"'
        '';
        expected = "compiled";
      };
    }
    // lib.optionalAttrs (native4 && (ruby.tvp.jit.zjit or false)) {
      zjit-functional = {
        script = ''
          ruby --zjit --zjit-stats --zjit-call-threshold=1 -e 'def answer(x); x * 2; end; 1000.times { abort unless answer(21) == 42 }; abort unless RubyVM::ZJIT.enabled? && RubyVM::ZJIT.stats[:compiled_iseq_count] > 0 && RubyVM::ZJIT.stats[:zjit_insn_count] > 0; print "compiled"'
        '';
        expected = "compiled";
      };
    };
})
// lib.optionalAttrs native4 (import ./native-launchers.nix { inherit package lib context; })
