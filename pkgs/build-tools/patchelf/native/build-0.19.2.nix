{
  tvp,
  lib,
  base,
  src,
  version,
  bash,
  coreutils,
  gnumake,
  gnused,
  gnugrep,
  gawk,
  diffutils,
  findutils,
  gnutar,
  bzip2,
  gzip,
  python,
  binutils,
  patchelf,
  cxxRuntime,
  doCheck ? true,
}:
let
  inherit (tvp.builder) steps outputs;
  elfPaths = [ "bin/patchelf" ];
in
final:
let
  environment = final.base.environment final.environment;
  command =
    name: run:
    environment
    // {
      inherit name run;
      cwd = "source";
    };
in
{
  pname = "patchelf";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  environment = {
    tools = [
      gnumake
      gnused
      gnugrep
      gawk
      diffutils
      findutils
      binutils
    ];
    libraries = [ cxxRuntime ];
    overrides.values.CONFIG_SHELL = "${bash}/bin/bash";
  };
  runtime = {
    libraries = [ cxxRuntime ];
    dlopenDirectories = [ ];
  };
  artifactPlan = steps.sequence [
    {
      name = "source.unpack";
      tools = [
        gnutar
        bzip2
        findutils
      ];
      run = ''
        mkdir source
        ${bzip2}/bin/bzip2 -dc ${final.src} | ${gnutar}/bin/tar -xf - --strip-components=1 -C source
        chmod -R u+w source
        epoch=$(find source -type f -printf '%T@\n' | sort -n | tail -n1)
        printf '%s\n' "''${epoch%%.*}" > source-date-epoch
      '';
    }
    (command "patchelf.configure" ''${bash}/bin/bash ./configure --prefix="$out"'')
    (command "patchelf.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
    (command "patchelf.install" ''${gnumake}/bin/make install'')
  ];
  inherit doCheck;
  upstreamPlan = steps.sequence [
    {
      name = "source.unpack";
      tools = [
        gnutar
        bzip2
        findutils
      ];
      run = ''
        mkdir source
        ${bzip2}/bin/bzip2 -dc ${final.src} | ${gnutar}/bin/tar -xf - --strip-components=1 -C source
        chmod -R u+w source
        epoch=$(find source -type f -printf '%T@\n' | sort -n | tail -n1)
        printf '%s\n' "''${epoch%%.*}" > source-date-epoch
      '';
    }
    (
      (steps.shebangs {
        name = "patchelf.test-shells";
        inherit python;
        paths = [
          "tests"
          "build-aux/test-driver"
        ];
        names = [
          "sh"
          "bash"
        ];
        interpreter = "${bash}/bin/bash";
      })
      // {
        enabled = doCheck;
      }
    )
    {
      name = "patchelf.test-loader";
      cwd = "source";
      tools = [ python ];
      enabled = doCheck;
      # This base does not install ldd. Use its actual ELF loader for the two
      # listing calls, retaining the fetched fixture's extraction/assertions.
      run = ''
        ${python}/bin/python3 - <<'PYTHON'
        from pathlib import Path
        p = Path("tests/replace-add-needed.sh")
        s = p.read_text()
        assert s.count("ldd ./simple") == 2
        p.write_text(s.replace("ldd ./simple", "${final.base.compiler.libc}/lib/ld-linux-x86-64.so.2 --list ./simple"))
        PYTHON
      '';
    }
    (command "patchelf.configure" ''${bash}/bin/bash ./configure --prefix="$out"'')
    (command "patchelf.build" ''${gnumake}/bin/make -j"$NIX_BUILD_CORES"'')
  ];
  upstreamCheck = (
    (command "patchelf.check" ''
        status=0
      ${gnumake}/bin/make -j"$NIX_BUILD_CORES" check SHELL=${bash}/bin/bash || status=$?
      cat tests/test-suite.log
      ${python}/bin/python3 -B ${./check-upstream.py} "$status" ${lib.escapeShellArg (lib.concatStringsSep ":" final.base.runtimeDirectories)} ${patchelf}/bin/patchelf
    '')
    // {
      enabled = final.doCheck;
    }
  );
  plan = steps.sequence (
    final.artifactPlan
    ++ [
      (steps.split "patchelf.finalize")
      (outputs.copyArtifacts { coreutils = final.coreutils; })
      {
        name = "output.manuals";
        tools = [ gzip ];
        run = ''
          ${gzip}/bin/gzip -n -9 "$out/share/man/man1/patchelf.1"
        '';
      }
      (outputs.strip {
        inherit python binutils;
        paths = elfPaths;
      })
      (outputs.rpaths {
        inherit python binutils patchelf;
        base = final.base;
        paths = elfPaths;
        libraries = final.runtime.libraries;
        dlopenDirectories = final.runtime.dlopenDirectories;
      })
      (outputs.checkPaths {
        inherit python binutils patchelf;
        paths = elfPaths;
      })
    ]
  );
  tvp.features = {
    inherit doCheck;
  };
  meta = {
    description = "Modify ELF interpreters, dependencies and runtime search paths";
    homepage = "https://github.com/NixOS/patchelf";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "patchelf";
  };
}
