# Follow upstream's pure-Go Linux release profile; compile with offline sources.
{
  tvp,
  lib,
  base,
  src,
  version,
  go,
  certificates,
  runtimeShell,
  vendorHash,
  revision,
}:
final:
let
  context = tvp.builder.forBase final.base;
  inherit (context) steps outputs tools;
  vendor = import ./vendor.nix {
    inherit (final)
      version
      src
      base
      go
      certificates
      ;
    sha256 = final.vendorHash;
  };
  command = steps.command { environment = final.environment; };
in
{
  pname = "grype";
  inherit
    base
    src
    version
    go
    certificates
    runtimeShell
    vendorHash
    revision
    ;
  inherit (tools) bash coreutils;
  artifactName = "${final.pname}-${final.version}";
  environment = {
    tools = [ final.go ];
    libraries = [ ];
  };
  runtime = {
    libraries = [ ];
    shell = final.runtimeShell;
    certificates = final.certificates;
  };
  dependencyProviders = {
    runtimeShell = final.runtime.shell;
    certificates = final.runtime.certificates;
  };
  plan = steps.sequence [
    (steps.unpack {
      src = final.src;
      compression = "gzip";
    })
    (command "grype.build" ''
      unset CC CXX
      export CGO_ENABLED=0 GOENV=off GOTOOLCHAIN=local GOPROXY=off GOSUMDB=off
      export GOCACHE="$TMPDIR/go-cache" GOPATH="$TMPDIR/go-path" GOMODCACHE="$TMPDIR/go-modules"
      cp -R ${vendor} vendor
      mkdir -p "$out/libexec" "$out/share/licenses/grype"
      build_date=$(date -u -d "@$(cat "$TVP_SOURCE_ROOT/source-date-epoch")" +%Y-%m-%dT%H:%M:%SZ)
      ${final.go}/bin/go build -mod=vendor -trimpath -buildvcs=false -p "$NIX_BUILD_CORES" \
        -tags containers_image_openpgp,exclude_graphdriver_btrfs \
        -ldflags "-s -w -buildid= -X main.version=${final.version} -X main.gitCommit=${final.revision} -X main.gitDescription=v${final.version} -X main.buildDate=$build_date" \
        -o "$out/libexec/grype" ./cmd/grype
      cp LICENSE "$out/share/licenses/grype/LICENSE"
    '')
    (steps.split "grype.finalize")
    (outputs.copyArtifacts { })
    {
      name = "grype.wrapper";
      tools = [ tools.sed ];
      run = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/grype" <<'TVP_GRYPE_WRAPPER'
        #!${final.runtime.shell}/bin/bash
        if test -z "''${SSL_CERT_FILE+x}"; then
          export SSL_CERT_FILE=${final.runtime.certificates}/etc/ssl/certs/ca-bundle.crt
        fi
        if test -z "''${SSL_CERT_DIR+x}"; then
          export SSL_CERT_DIR=${final.runtime.certificates}/etc/ssl/certs
        fi
        exec @out@/libexec/grype "$@"
        TVP_GRYPE_WRAPPER
        sed -i "s,@out@,$out,g" "$out/bin/grype"
        chmod +x "$out/bin/grype"
      '';
    }
    (outputs.checkPaths { paths = [ "libexec/grype" ]; })
  ];
  meta = {
    description = "Vulnerability scanner for explicit package inventories and SBOMs";
    homepage = "https://github.com/anchore/grype";
    license = lib.licenses.asl20;
    mainProgram = "grype";
    platforms = [ final.base.platform.system ];
  };
}
