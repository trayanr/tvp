# Runtime composition: the engine and module packages are already built.
{
  lib,
  tvp,
  php,
  extensions ? [ ],
  settings ? { },
}:
let
  engine = php.unwrapped or php;
  names = map (extension: extension.extensionName) extensions;
  fail = message: throw "PHP runtime: ${message}";
  checked =
    assert lib.all lib.isDerivation extensions || fail "extensions must be packages";
    assert
      lib.all (
        extension: extension ? php && extension ? modulePath && extension ? extensionName
      ) extensions
      || fail "expected PHP extension packages";
    assert
      builtins.length names == builtins.length (lib.unique names) || fail "duplicate extension names";
    extensions;
  iniValue =
    value:
    if lib.isBool value then
      (if value then "On" else "Off")
    else if lib.isInt value || lib.isFloat value then
      toString value
    else if builtins.isString value && !(lib.hasInfix "\n" value || lib.hasInfix "\r" value) then
      "\"${
        lib.replaceStrings
          [
            "\\"
            "\""
          ]
          [
            "\\\\"
            "\\\""
          ]
          value
      }\""
    else
      fail "INI settings must be strings, numbers or booleans without line breaks";
  moduleArgs = builtins.listToAttrs (
    map (extension: lib.nameValuePair "extension-${extension.extensionName}" extension) checked
  );
  moduleOrder = map (extension: "extension-${extension.extensionName}") checked;
  argumentNames = [
    "php"
    "base"
    "settings"
  ] ++ builtins.attrNames moduleArgs;
  recipe = lib.setFunctionArgs (
    args: final:
    let
      context = tvp.builder.forBase final.base;
      inherit (context) tools steps outputs;
      modules = map (name: final.${name}) moduleOrder;
      effectiveNames = map (extension: extension.extensionName) modules;
      valid =
        assert
          lib.all (
            extension:
            lib.isDerivation extension && extension ? php && extension ? modulePath && extension ? extensionName
          ) modules
          || fail "expected PHP extension packages";
        assert
          builtins.length effectiveNames == builtins.length (lib.unique effectiveNames)
          || fail "duplicate extension names";
        assert
          lib.all (extension: extension.php.drvPath == final.php.drvPath) modules
          || fail "an extension was built for a different PHP; select it from this PHP's extensions catalogue";
        assert
          lib.all (
            key:
            builtins.match "[A-Za-z_][A-Za-z0-9_.-]*" key != null
            && !(builtins.elem key [
              "extension"
              "zend_extension"
              "extension_dir"
            ])
          ) (builtins.attrNames final.settings)
          || fail "invalid or reserved INI setting name";
        true;
      config =
        # PHP 5.2 prefixes extension_dir even when a module path is absolute.
        lib.optionalString
          (
            modules != [ ]
            && builtins.compareVersions final.php.version "5.2" >= 0
            && builtins.compareVersions final.php.version "5.3" < 0
          )
          ''
            extension_dir="/"
          ''
        + lib.concatMapStrings (
          extension: "${extension.loader}=${iniValue "${extension}/${extension.modulePath}"}\n"
        ) modules
        + lib.concatStrings (lib.mapAttrsToList (key: value: "${key}=${iniValue value}\n") final.settings);
    in
    (builtins.intersectAttrs moduleArgs args)
    // {
      pname = "php-with-extensions";
      version = final.php.version;
      inlineScripts = true;
      inherit (args) php base settings;
      inherit (tools) bash coreutils;
      src = null;
      passthru = {
        unwrapped = final.php;
        enabledExtensions = modules;
        inherit (final) settings;
      };
      plan =
        assert valid;
        [
          {
            name = "php-runtime.link-engine";
            tools = [ tools.coreutils ];
            run = ''
              mkdir -p "$out/bin"
              for executable in ${final.php}/bin/*; do
                ln -s "$executable" "$out/bin/$(basename "$executable")"
              done
              for directory in include lib share; do
                if [ -e "${final.php}/$directory" ]; then
                  ln -s "${final.php}/$directory" "$out/$directory"
                fi
              done
            '';
          }
          (steps.split "php-runtime.finalize")
          (outputs.copyArtifacts { })
          {
            name = "php-runtime.configure";
            tools = [ tools.coreutils ];
            run = ''
              mkdir -p "$out/etc/php/conf.d"
              printf '%s' ${lib.escapeShellArg config} > "$out/etc/php/php.ini"
              for executable in php php-cgi phpdbg; do
                if [ -e "${final.php}/bin/$executable" ]; then
                  rm "$out/bin/$executable"
                  cat > "$out/bin/$executable" <<SCRIPT
              #!${tools.bash}/bin/bash
              export PHP_INI_SCAN_DIR="$out/etc/php/conf.d"
              exec "${final.php}/bin/$executable" -c "$out/etc/php/php.ini" "\$@"
              SCRIPT
                  chmod +x "$out/bin/$executable"
                fi
              done
            '';
          }
        ];
      meta = final.php.meta // {
        description = "PHP with selected extensions and INI settings";
        mainProgram = "php";
      };
    }
  ) (lib.genAttrs argumentNames (_: true));
in
tvp.builder {
  inherit recipe;
  args = {
    php = engine;
    inherit settings;
  } // moduleArgs;
  argumentDefaults =
    { specification, ... }:
    {
      base = specification.php.specification.base;
    };
  dependencyNames = [ "php" ] ++ builtins.attrNames moduleArgs;
  metadata.kind = "php-runtime";
  selection.kind = "composition";
  mkTests = _: { };
}
