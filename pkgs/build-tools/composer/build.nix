{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  unzip,
}:
final:
let
  inherit (tvp.builder.forBase final.base) steps outputs tools;
in
{
  pname = "composer";
  inherit
    base
    src
    version
    php
    unzip
    ;
  inherit (tools) bash coreutils;
  dependencyProviders = {
    inherit (final.runtime) php unzip;
  };
  runtime = {
    shell = final.bash;
    inherit (final) php unzip;
  };
  plan = steps.sequence [
    {
      name = "composer.install-release";
      tools = [ final.coreutils ];
      run = ''
        install -Dm444 ${final.src} "$out/libexec/composer/composer.phar"
      '';
    }
    (steps.split "composer.finalize")
    (outputs.copyArtifacts { })
    {
      name = "composer.launcher";
      tools = [ final.coreutils ];
      run = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/composer" <<EOF
        #!${final.runtime.shell}/bin/bash
        export PATH="${final.runtime.unzip}/bin\''${PATH:+:\$PATH}"
        exec ${final.runtime.php}/bin/php "$out/libexec/composer/composer.phar" "\$@"
        EOF
        chmod 0555 "$out/bin/composer"
      '';
    }
  ];
  meta = {
    description = "Dependency manager for PHP";
    homepage = "https://getcomposer.org/";
    license = lib.licenses.mit;
    mainProgram = "composer";
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}
