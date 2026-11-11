{
  tvp,
  tvpLib,
  candidate,
  constructionTool,
  fetchurl,
}:
tvpLib.packages.mkDefs {
  "3.0.9" = {
    constructor = tvp.builder;
    builder = ./build-3.0.9.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = false;
        "shared" = true;
        "static" = true;
        "variadic" = false;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi-dg.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
          {
            "path" = "testsuite/libffi.call/err_bad_abi.c";
            "before" = "args[0] = NULL;";
            "after" = "args[0] = NULL;\n        (void)args;";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "mdate-sh"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.0.10" = {
    constructor = tvp.builder;
    builder = ./build-3.0.9.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = false;
        "shared" = true;
        "static" = true;
        "variadic" = false;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "mdate-sh"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.0.11" = {
    constructor = tvp.builder;
    builder = ./build-3.0.9.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = false;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "documentedData" = {
          "testsuite/libffi.call/a.out" = {
            "magic" = "7f454c4602010100";
            "mode" = 493;
            "sha256" = "a8dcdd09dbb6110ba74176197c3ca5a640a178f1af7763a98e5d42312132ee42";
          };
        };
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "mdate-sh"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.0.12" = {
    constructor = tvp.builder;
    builder = ./build-3.0.9.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = false;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "mdate-sh"
          "libtool-ldflags"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.1" = {
    constructor = tvp.builder;
    builder = ./build-3.1.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = false;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "mdate-sh"
          "libtool-ldflags"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.3" = {
    constructor = tvp.builder;
    builder = ./build-3.3.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = true;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "doc/mdate-sh"
          "libtool-ldflags"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.4.3" = {
    constructor = tvp.builder;
    builder = ./build-3.3.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "cFlags" = [ "-Wno-error=implicit-function-declaration" ];
      "features" = {
        "headersInIncludedir" = true;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = false;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "doc/mdate-sh"
          "libtool-ldflags"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.5.0" = {
    constructor = tvp.builder;
    builder = ./build-3.3.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = true;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = true;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "doc/mdate-sh"
          "libtool-ldflags"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
    };
  };
  "3.6.0" = {
    constructor = tvp.builder;
    builder = ./build-3.3.nix;
    base = candidate.base;
    source =
      { version, sha256 }:
      fetchurl {
        urls = [
          "https://sourceware.org/pub/libffi/libffi-${version}.tar.gz"
          "https://github.com/libffi/libffi/releases/download/v${version}/libffi-${version}.tar.gz"
        ];
        inherit sha256;
      };
    testContext =
      package:
      tvpLib.tests.fromPackage {
        builder = tvp.builder;
        inherit package;
      };
    helpers = {
      inherit tvp;
    };
    deps = {
      file = tvp.packages.file;
      bash = constructionTool "bash";
      coreutils = constructionTool "coreutils";
      pkgConfig = constructionTool "pkgConfig";
      gnumake = constructionTool "make";
      gnutar = constructionTool "tar";
      python = constructionTool "python";
      binutils = constructionTool "binutils";
      patchelf = constructionTool "patchelf";
      sed = constructionTool "sed";
      grep = constructionTool "grep";
      gawk = constructionTool "gawk";
      diffutils = constructionTool "diffutils";
      findutils = constructionTool "findutils";
      gzip = constructionTool "gzip";
      dejagnu = tvpLib.packages.withConstraint {
        category = "construction";
        reason = "Retained source GCC DejaGnu/Expect/Tcl harness independently exercises libffi ABI and closures.";
      } (import ../../../../bootstrap/source-gcc-test-harness.nix { }).dejagnu;

    };
    opts = {
      "features" = {
        "headersInIncludedir" = true;
        "shared" = true;
        "static" = true;
        "variadic" = true;
        "versionFunction" = true;
      };
      "preparation" = {
        # Bind C test dialect without leaking it into C++ or TOOL_OPTIONS.
        edits = [
          {
            "path" = "testsuite/lib/libffi.exp";
            "before" = "proc libffi_target_compile { source dest type options } {";
            "after" = "proc libffi_target_compile { source dest type options } {\n    global env\n    if {[file extension $source] eq \".c\" && $env(TVP_TEST_C_STANDARD) ne \"\"} {\n        lappend options \"additional_flags=-std=$env(TVP_TEST_C_STANDARD)\"\n    }";
            "count" = 1;
          }
        ];
        "libtoolAnchors" = {
          "ltmain.sh" = 1;
        };
        "selections" = [
          "configure"
          "config.sub"
          "config.guess"
          "install-sh"
          "compile"
          "depcomp"
          "missing"
          "ltmain.sh"
          "testsuite"
          "doc/mdate-sh"
          "libtool-ldflags"
        ];
        "shellFragments" = {
          "ltmain.sh" = [
            "# Generated from ltmain.m4sh."
            "\n# libtool (GNU libtool) 2.4"
            "\n# libtool (GNU libtool) 2.4.2"
          ];
        };
      };
      "reportedVersion" = "3.5.2";
    };
  };
}
