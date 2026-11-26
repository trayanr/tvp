# Package application source and assets over an already locked Ruby environment.
{ lib }:
{
  tvp,
  bundle,
  name,
  version,
  src,
  commands,
  tools ? [ ],
  buildScript ? "",
  environment ? { },
}:
let
  fail = message: throw "TVP Ruby application: ${message}";
  validName =
    value: builtins.isString value && builtins.match "[A-Za-z0-9][A-Za-z0-9_.+-]*" value != null;
  recipe =
    {
      base,
      bundle,
      name,
      version,
      src,
      commands,
      tools,
      buildScript,
      environment,
    }:
    final:
    let
      baseTools = (tvp.builder.forBase final.base).tools;
      defaults = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (key: value: ''
          if test "''${${key}+x}" != x; then
            export ${key}=${lib.escapeShellArg value}
          fi
        '') final.environment
      );
      manifest = builtins.toJSON {
        name = final.pname;
        bundle = toString final.bundle;
        shell = "${baseTools.bash}/bin/bash";
        inherit (final) commands environment;
      };
    in
    {
      pname = name;
      inherit
        base
        bundle
        version
        src
        commands
        tools
        buildScript
        environment
        ;
      inherit (baseTools) bash coreutils;
      plan =
        assert validName final.pname || fail "name must be a safe application directory name";
        assert (final.bundle.tvp.kind or null) == "ruby-bundle" || fail "bundle must be a TVP Ruby bundle";
        assert
          builtins.isAttrs final.commands && final.commands != { }
          || fail "provide at least one named command";
        assert
          lib.all validName (builtins.attrNames final.commands)
          || fail "command names must be safe executable names";
        assert
          lib.all (
            argv:
            builtins.isList argv
            && argv != [ ]
            && lib.all builtins.isString argv
            && validName (builtins.head argv)
          ) (builtins.attrValues final.commands)
          || fail "commands must be nonempty argv lists starting with a bundle executable name";
        assert
          builtins.isAttrs final.environment
          && lib.all (
            key:
            builtins.match "[A-Za-z_][A-Za-z0-9_]*" key != null && builtins.isString final.environment.${key}
          ) (builtins.attrNames final.environment)
          || fail "environment must map valid variable names to string defaults";
        [
          {
            name = "ruby-application.package";
            tools = [
              final.bundle
              baseTools.diffutils
            ]
            ++ final.tools;
            run = ''
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME" source
              test -d ${lib.escapeShellArg "${final.src}"}
              cp -R ${lib.escapeShellArg "${final.src}/."} source/
              chmod -R u+w source
              cd source
              for file in Gemfile Gemfile.lock; do
                if test -e "$file" || test -L "$file"; then
                  cmp "${final.bundle}/project/$file" "$file"
                  rm -f "$file"
                fi
                cp "${final.bundle}/project/$file" "$file"
                chmod u+w "$file"
              done
              (
                :
                ${defaults}
                ${final.buildScript}
              )
              cmp "${final.bundle}/project/Gemfile" Gemfile
              cmp "${final.bundle}/project/Gemfile.lock" Gemfile.lock
              mkdir -p "$out/share/${final.pname}"
              cp -R . "$out/share/${final.pname}/"
              chmod -R a-w "$out/share/${final.pname}"
              printf '%s' ${lib.escapeShellArg manifest} > "$TVP_SOURCE_ROOT/application.json"
              ${final.bundle}/bin/ruby ${./application-wrapper.rb} "$TVP_SOURCE_ROOT/application.json" "$out"
            '';
          }
        ];
      passthru =
        package:
        {
          inherit (final) bundle;
          inherit (final.bundle)
            ruby
            bundler
            gems
            groups
            ;
          applicationDirectory = "${package}/share/${final.pname}";
        }
        // lib.optionalAttrs (final.bundle ? tvpInventory) {
          inherit (final.bundle) tvpInventory;
        };
    };
in
tvp.builder {
  inherit recipe;
  args = {
    inherit
      bundle
      name
      version
      src
      commands
      tools
      buildScript
      environment
      ;
  };
  argumentDefaults = { arguments, ... }: { base = arguments.bundle.ruby.specification.base; };
  dependencyNames = [ "bundle" ];
  metadata = {
    builder = "application.nix";
    definition = name;
    kind = "ruby-application";
    status.level = "ok";
  };
  selection = {
    kind = "composition";
    category = "ruby-application";
  };
  mkTests = _: { };
}
