# Build one locked gem against the selected Ruby and its native compiler base.
{
  tvp,
  lib,
  base,
  ruby,
  src,
  gemName,
  version,
  dependencies ? [ ],
  libraries ? [ ],
  tools ? [ ],
  buildFlags ? [ ],
  patches ? [ ],
  sourceType ? "gem",
  sourceSubdir ? ".",
  platform ? "ruby",
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs;
  baseTools = context.tools;
  environment = final.base.environment final.environment;
  quote = lib.escapeShellArg;
  paths = [ final.ruby.gemPath ];
  fullName = "${final.gemName}-${final.version}${
    lib.optionalString (final.platform != "ruby") "-${final.platform}"
  }";
  prepareSource =
    if final.sourceType == "gem" && final.patches == [ ] then
      ''
        ${final.ruby}/bin/ruby ${./gem-source.rb} verify ${quote "${final.src}"} ${quote final.gemName} ${quote final.version} ${quote final.platform}
        cp ${quote "${final.src}"} package.gem
      ''
    else
      ''
        mkdir source
        ${
          if final.sourceType == "gem" then
            ''
              ${final.ruby}/bin/ruby ${./gem-source.rb} verify ${quote "${final.src}"} ${quote final.gemName} ${quote final.version} ${quote final.platform}
              ${final.ruby}/bin/ruby ${./unpack-gem.rb} ${quote "${final.src}"} "$TVP_SOURCE_ROOT/source"
            ''
          else
            ''
              if test -d ${quote "${final.src}"}; then
                cp -R ${quote "${final.src}/."} source/
              else
                tar -xf ${quote "${final.src}"} --strip-components=1 -C source
              fi
            ''
        }
        chmod -R u+w source
        cd source/${quote final.sourceSubdir}
        ${lib.concatMapStringsSep "\n" (patch: "patch -p1 < ${quote "${patch}"}") final.patches}
        ${final.ruby}/bin/ruby ${./normalize-source-links.rb} "$TVP_SOURCE_ROOT/source"
        ${lib.optionalString (final.sourceType == "git") ''
          export HOME="$TMPDIR"
          if ! test -e "$TVP_SOURCE_ROOT/source/.git"; then
            git -C "$TVP_SOURCE_ROOT/source" init --quiet
          fi
          git -C "$TVP_SOURCE_ROOT/source" add --all --force
        ''}
        ${final.ruby}/bin/ruby ${./gem-source.rb} ${
          if final.sourceType == "git" then "build-git" else "build"
        } "$TVP_SOURCE_ROOT/package.gem" ${quote final.gemName} ${quote final.version} ${quote final.platform}
      '';
in
{
  pname = "ruby-${final.gemName}";
  inherit
    base
    ruby
    src
    gemName
    version
    dependencies
    libraries
    tools
    buildFlags
    patches
    sourceType
    sourceSubdir
    platform
    ;
  inherit (baseTools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [
      final.ruby
      baseTools.gnumake
      baseTools.pkg-config
      baseTools.gnutar
      baseTools.gzip
      baseTools.xz
      baseTools.bzip2
      baseTools.patch
    ]
    ++ lib.optionals (final.sourceType == "git") [ tvp.packages.git ]
    ++ final.tools;
    libraries = [
      final.ruby
    ]
    ++ (final.ruby.runtime.libraries or [ ])
    ++ final.dependencies
    ++ final.libraries;
  };
  runtime.libraries = [
    final.ruby
  ]
  ++ (final.ruby.runtime.libraries or [ ])
  ++ final.dependencies
  ++ final.libraries;
  development = {
    includeDirectories = [ ];
    libraryDirectories = [ ];
    pkgconfig = [ ];
  };
  plan =
    assert
      lib.all (
        dependency: dependency ? ruby && dependency.ruby.drvPath == final.ruby.drvPath
      ) final.dependencies
      || throw "TVP Ruby gem: dependencies must be built for the selected Ruby";
    assert
      builtins.elem final.sourceType [
        "gem"
        "source"
        "git"
      ]
      || throw "TVP Ruby gem: sourceType must be gem, source or git";
    assert
      final.sourceSubdir == "."
      || (
        builtins.match "[A-Za-z0-9_][A-Za-z0-9_./+-]*" final.sourceSubdir != null
        && !(builtins.elem ".." (lib.splitString "/" final.sourceSubdir))
      )
      || throw "TVP Ruby gem: sourceSubdir must remain inside the source tree";
    steps.sequence [
      (
        environment
        // {
          name = "gem.prepare";
          run = prepareSource;
        }
      )
      (
        environment
        // {
          name = "gem.install";
          run = ''
            export HOME="$TMPDIR"
            export GEM_HOME="$out/${final.ruby.gemPath}"
            export MAKEFLAGS="-j$NIX_BUILD_CORES"
            mkdir -p "$GEM_HOME"
            if ${final.ruby}/bin/gem install --local --force --ignore-dependencies \
              --install-dir "$GEM_HOME" --build-root / --no-env-shebang --no-document \
              "$TVP_SOURCE_ROOT/package.gem" -- ${lib.escapeShellArgs final.buildFlags}; then
              :
            else
              status=$?
              ${baseTools.findutils}/bin/find "$GEM_HOME" -name mkmf.log -exec cat {} + >&2
              exit "$status"
            fi
            ${final.ruby}/bin/ruby ${./gem-source.rb} installed "$GEM_HOME" ${quote final.gemName} ${quote final.version} ${quote final.platform}
          '';
        }
      )
      (steps.split "gem.finalize")
      (outputs.copyArtifacts { })
      {
        name = "gem.cleanup";
        tools = [ final.ruby ];
        run = ''
          ${final.ruby}/bin/ruby ${./gem-source.rb} cleanup "$out" ${quote final.ruby.gemPath} "$TVP_ARTIFACT_ROOT"
        '';
      }
      (outputs.development { libraries = final.dependencies; })
      (outputs.interpreters {
        inherit paths;
        nativeOnly = true;
        loader = "${final.base.compiler.libc}/${final.base.platform.dynamicLinker}";
      })
      (outputs.rpaths {
        inherit paths;
        nativeOnly = true;
        base = final.base;
        libraries = final.runtime.libraries;
      })
      (outputs.strip {
        inherit paths;
        nativeOnly = true;
      })
      (outputs.checkPaths {
        inherit paths;
        nativeOnly = true;
      })
    ];
  passthru = {
    tvpInventory = {
      schema = 1;
      packages = {
        runtime = final.ruby;
        native = final.libraries;
      };
    };
    ruby = final.ruby;
    gemName = final.gemName;
    gemPath = final.ruby.gemPath;
    inherit fullName;
    gemSpecPath = "${final.ruby.gemPath}/specifications/${fullName}.gemspec";
    rubyDevelopment.gemDirectories = [ final.ruby.gemPath ];
  };
  meta = {
    description = "${final.gemName} Ruby gem for Ruby ${final.ruby.version}";
    platforms = [ final.base.platform.system ];
  };
}
