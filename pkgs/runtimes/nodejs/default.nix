{ pkgs, tvp }:
let
  pname = "nodejs";
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-18.14.0.nix;
        # Keep this V8 era on the GCC 9 source profile.
        base = tvp.bases.gcc_9.full;
        deps = {
          # Configure accepts this Python release and GYP requires ctypes.
          python = tvp.packages.python_3_11;
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "18.14.0" = "sha256-Qu+d0xmT1cjoKwqwlpE1CT5qKW76J7G+mvwErADwJno=";
        "18.14.1" = "sha256-7sNTQ4Jm/QrvU6lEa+ELMu5udNCOMt1UVLOC/2eT2gQ=";
        "18.14.2" = "sha256-+8Nk3SX+4srMDyAz2y2GEV/AdXUxDqDmRAi4Fw0JxoU=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        # Built-in SQLite first shipped in Node.js 22.5.0.
        opts.sqlite = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
          {
            file = ./patches/worker-inspector-stdint.patch;
            reason = "Include the declaration of uint64_t used by the worker inspector, as in newer Node.js.";
          }
          {
            file = ./patches/simdjson-formatter-gcc16.patch;
            reason = "Backport simdjson's explicit CRTP formatter dispatch for GCC 16.";
          }
        ];
      };
      releases = {
        "22.0.0" = "sha256-IuKPv/MfaQc7gCTLQnReUQX4QEHzR1smC5fVoUEDnRo=";
        "22.1.0" = "sha256-nX1fQNnb1iYMmbXklLX5vHVejw/6xw4SGtzl+0QvI8s=";
        "22.2.0" = "sha256-iJkIqIKNFISRDX5lm2qlet6NUo/w45Dpp372WadihHQ=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        # Built-in SQLite first shipped in Node.js 22.5.0.
        opts.sqlite = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
          {
            file = ./patches/worker-inspector-stdint.patch;
            reason = "Include the declaration of uint64_t used by the worker inspector, as in newer Node.js.";
          }
        ];
      };
      releases = {
        "22.3.0" = "sha256-v7hb0dylF3YfkEbWFgD4MNGZNdbWw27e0BV4oZMmEEw=";
        "22.4.0" = "sha256-KStDAITy8ykT3H2k6y+8iWklJ3Kp0b/ormxLSpjKOtM=";
        "22.4.1" = "sha256-ZfyFf1qoJWqvyQCzRMARXJrq4loCVB/Vzg29Tf0cX7k=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        # Built-in SQLite requires a CLI flag until Node.js 22.13.0.
        opts.sqliteRequiresFlag = true;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
          {
            file = ./patches/worker-inspector-stdint.patch;
            reason = "Include the declaration of uint64_t used by the worker inspector, as in newer Node.js.";
          }
        ];
      };
      releases = {
        "22.5.0" = "sha256-WoYjjwA5NxagPNME98Y/TCcUSInQWjk4uw8kLI0p1i8=";
        "22.5.1" = "sha256-kk84GjLPJra+2+lf7t3jSEUPT9MhKD078/eWWqRc6DE=";
        "22.6.0" = "sha256-NyWdYY1VZcpVrMJYUEXH4cW5llo9TrRMCiN/2uhLnUQ=";
        "22.7.0" = "sha256-HgtvLyyk+wtGRKETYxadr0t8QvAOWlPSxlqf3EY+fYg=";
        "22.8.0" = "sha256-8TDoIXbR7gcC2Zr8GZXQBhv47TV8OINKMqCMnvdPGsc=";
        "22.9.0" = "sha256-pVrrNo3uk0MvYQEnz5TOaCqsB7k9y7qt2FbfEiySOd8=";
        "22.10.0" = "sha256-MYBxDTEwrZ3wFGar8BDkCNQbN0vlQwHRSA0Q7Kc1WOA=";
        "22.11.0" = "sha256-u/Apd2HVOu/anXhVxXx9LCcrg6e1utT+qcspAG2OHTU=";
        "22.12.0" = "sha256-/hvEvgBNwSch6iy2cbCKId4BxpdpYO+KEkh5hYlnnhY=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
          {
            file = ./patches/worker-inspector-stdint.patch;
            reason = "Include the declaration of uint64_t used by the worker inspector, as in newer Node.js.";
          }
        ];
      };
      releases = {
        "22.13.0" = "sha256-5Q22cwcWuirpU8+Z0QyAKVvTO7ctPIKdnpn2r1bWJsc=";
        "22.13.1" = "sha256-z84oIRk5D34MIiBBCSRCjpDa3LLfF0TAxKDnuq44fMI=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
        ];
      };
      releases = {
        "22.14.0" = "sha256-xgmUa/eTtVx5VMJlgnYICNVMFhhdecsvuIBl5S3iGRQ=";
        "22.15.0" = "sha256-58QibR2S8zrYVNbaT35RnndpC45z+TSWiB+MU5F02d8=";
        "22.15.1" = "sha256-wZ8Bd9IcYhdGYl5fN1kL0NeacgQ7d7U3hMul8UXnJj4=";
        "22.16.0" = "sha256-cgiU8yPlwawklo6yZ2ZgyQcw1xXLfwkL5xpmhmKhfDc=";
        "22.17.0" = "sha256-ej7yrtuQXqeSblIJFXJm4jdqXbYZ2awMujyWf29dtPk=";
        "22.17.1" = "sha256-MnQV/Xb867mBM79W4tkOOsBIsDj6wmdvA7bbkQdFdbk=";
        "22.18.0" = "sha256-Eg4PdEGQl6n6+uH9gLned5Glh+bxxIwisZMjnM0PcIQ=";
        "22.19.0" = "sha256-AnKs/OUM6a0GAogyGxCScZp/GZZvgUGYNUEMWcCdqkY=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_5;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
        ];
      };
      releases = {
        "22.20.0" = "sha256-/3pqbooTEq9YdeQAWDUcT4kNKKtkwy8SsswZmvoiAC0=";
        "22.21.0" = "sha256-eRsY6WnqIsyVIQjujqr7sSzd/Zc7u7C3/BFjlcDZqBw=";
        "22.21.1" = "sha256-SH1z/U2wDcJCDWWagiGxgaeTf7xbxz8xwwsWgK1t7Wo=";
        "22.22.0" = "sha256-TBOAErtTUvSYIqjz5tHbceAGOdDDbVtnVvkeTG8wtoM=";
        "22.22.1" = "sha256-hxBLB+es7nSLzFOR4bxpzzVxyqD9+4sda1/T+VmbeEk=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.12 is accepted throughout the Node.js 22 line.
          python = tvp.packages.python_3_12;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the upstream OpenSSL minor line.
          openssl = tvp.packages.openssl_3_5;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
        ];
      };
      releases = {
        "22.22.2" = "sha256-tr7dOoys1d998BWlCIJksSx0one6YGhMuWQq6Ot0MTI=";
        "22.22.3" = "sha256-8+aleNsaszWkpyeFweh60Yos9tL8JXR6HXQfs0rwvQ8=";
        "22.23.0" = "sha256-Os+uEAx7hVpMdlIO4PlcrcrOP0JU8Wt9SIfxePyV1KA=";
        "22.23.1" = "sha256-snOF1oRQib25EoXZSwbCpc8cN/gXOjxOEIJMwf+t6ro=";
        "22.23.2" = "sha256-u+do341YFdf6dhJAUphTMkUuCkdC058yAnVQ0aq49vs=";
        "22.23.3" = "sha256-vZcJPhoekkMziVDBdKaTpk1OCSapxs4lmWK8WNXpaQk=";
        "22.23.4" = "sha256-e5rcgtYS0KKoY9lsRt4iklUuJQzuUZVuu+AUbEKqyuk=";
        "22.23.5" = "sha256-bM58WL8FhwDGQ5RJA9YKMl6MnO7eH1wsCItDXyraCRo=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.13 is accepted throughout the Node.js 23 line.
          python = tvp.packages.python_3_13;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Upstream ships OpenSSL 3.0 throughout this release line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        # The built-in SQLite module is gated by its CLI flag before 23.4.0.
        opts.sqliteRequiresFlag = true;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
          {
            file = ./patches/worker-inspector-stdint.patch;
            reason = "Include the declaration of uint64_t used by the worker inspector, as in newer Node.js.";
          }
        ];
      };
      releases = {
        "23.0.0" = "sha256-ecgAssl8SXv33iGsdDXcX1h8fUc191AFasYxDUO3nso=";
        "23.1.0" = "sha256-V8v9PdUfkwDqK45gqO0hWx6qcfveTDkDp9MaRDpKRCM=";
        "23.2.0" = "sha256-PPeoo2aCd1aTaR8d6QG7WXOtPAriqoexrdneUV57L8c=";
        "23.3.0" = "sha256-Qqa1YRruxnI/S2+Y8cIF/B+jI5nfQdvtaicIOv1IxcE=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.13 is accepted throughout the Node.js 23 line.
          python = tvp.packages.python_3_13;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Upstream ships OpenSSL 3.0 throughout this release line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
          {
            file = ./patches/worker-inspector-stdint.patch;
            reason = "Include the declaration of uint64_t used by the worker inspector, as in newer Node.js.";
          }
        ];
      };
      releases = {
        "23.4.0" = "sha256-S7FL8/r3kLsSKlN7Bde/QAb8UeeHYbFXzkU7Y/p+M3E=";
        "23.5.0" = "sha256-Mud7NsB3TGi6q0G8fCrMWGY8oKK3xNPpvsb3YcFf2sA=";
        "23.6.0" = "sha256-1vPxNtwm1hvRuvriqfwNXn9xOm8AZ8XhA1G8fKZXTc0=";
        "23.6.1" = "sha256-/vpJ3t6HMwGK2k4w+IWAjMTiIWe4rjIzxtaiNzev928=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.13 is accepted throughout the Node.js 23 line.
          python = tvp.packages.python_3_13;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Upstream ships OpenSSL 3.0 throughout this release line.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/v8-type-hints-stdint.patch;
            reason = "Include the declaration of uint8_t used in this V8 header, as in newer V8.";
          }
        ];
      };
      releases = {
        "23.7.0" = "sha256-jeGS7y/uLuiiMN2NDpruGC7pyYVszbX9lRiKvoT3ckI=";
        "23.8.0" = "sha256-bsXVTQ6EI/xZhvbvpPZh6DcGWYGLFPRYzcnRufddO4g=";
        "23.9.0" = "sha256-xrQgvtuwSaZTjDOvKKuviQEczIefDw+BeRZ1Jjwjj5c=";
        "23.10.0" = "sha256-s55fvT3ruDGN3qavPomwfa+4kUIft8qZ++Gcma2r5f0=";
        "23.11.0" = "sha256-8sXbIfxdPD14x+iCO/93DO8NqAeMO1rE+m0X1aQb6Z0=";
        "23.11.1" = "sha256-rvbGc5XDKDdrZlvO78nRegailh+akrkwGd/zmFTVsu8=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.13 is accepted throughout the Node.js 24 line.
          python = tvp.packages.python_3_13;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the OpenSSL minor line shipped in these upstream releases.
          openssl = tvp.packages.openssl_3_0;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "24.0.0" = "sha256-kU8/GwP4SgmU1zV/GQ/xPAOIAMaTtsBtoikOtYjIJ2E=";
        "24.0.1" = "sha256-cCcQJpcYCECaftZEQ2DV/j70FGwcpT8sopDGDSFL6E4=";
        "24.0.2" = "sha256-FZcHWvwG5cYUXQv7134gcsLsCrcaxJUM8AiyZBN0zXE=";
        "24.1.0" = "sha256-yBcbKuzLKMjFNH8nOiWtrhcvsqZbyMl1vCLsWJSdDq8=";
        "24.2.0" = "sha256-QBQ9Q++97rlTeZX1MhJsSU1jox2jMqy1Ai928Ar8Yqs=";
        "24.3.0" = "sha256-62iO+KY/2p68C1+QdgmkbibbbZrO78CDIAmpg3Hpku0=";
        "24.4.0" = "sha256-QvqAedolqSYBPNibnTRn0JEQ5PuwxDk0Lr5N1uzCa7s=";
        "24.4.1" = "sha256-rbecoJh0hu1mE2IT2hn/F+9nJNyzQMMg4BDJRCEBZS8=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.13 is accepted throughout the Node.js 24 line.
          python = tvp.packages.python_3_13;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the OpenSSL minor line shipped in these upstream releases.
          openssl = tvp.packages.openssl_3_5;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell-24.0.0.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "24.5.0" = "sha256-8bqWIEckvRxt53WOCLNxi6C0XYf7O+vX4wCXh0zMgTA=";
        "24.6.0" = "sha256-itXDh7XVXY87eDsPGyG64Do7OxCsiaJdJmz/p7eV6EI=";
        "24.7.0" = "sha256-z3Snd1O2Kf/r0uOPsVOiEAGyt6PDZcDsczKxILmMclE=";
        "24.8.0" = "sha256-HAOzYuv0dA1HWLmj0wh+PemJ9UgjZQ7IC0cJDvQUsuA=";
        "24.9.0" = "sha256-8XvEywH1kJjDSiiMG7EJp3iGfBTusOu9YI0GF7EZO78=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Python 3.13 is accepted throughout the Node.js 24 line.
          python = tvp.packages.python_3_13;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # Match the OpenSSL minor line shipped in these upstream releases.
          openssl = tvp.packages.openssl_3_5;
          zlib = tvp.packages.zlib_1;
        };
        # This release line has no Temporal configure flag.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "24.10.0" = "sha256-8X42yyzIw0qSFbpXtVznkbEC4pNDLtR61jy68V94Z48=";
        "24.11.0" = "sha256-z5yQbUZEZHH5VbHyxqzopGFQHYLSfhroWV3LOw4sMSo=";
        "24.11.1" = "sha256-6k2jXxyco3bsaDfh4wzuMNSRhH/hUqPwN43BFW2VS70=";
        "24.12.0" = "sha256-bT6JGgFrkPbGoZ6ly8nJDFfu+RmGcLqT8E+oKvAldK4=";
        "24.13.0" = "sha256-Mg/pCcuzR9z1FiAeSWTvF3uBON+af4ENDVSVBIGzFYs=";
        "24.13.1" = "sha256-sie8ho+16eyGcGIOKyVTDrEsF9Q+bHvFG7OKZgaEGS0=";
        "24.14.0" = "sha256-n+Al70Aoq6ldFueBBRi/Sl6Kv7C9wH2KP9uwr9U4138=";
        "24.14.1" = "sha256-eCJQdxPyAs8qVRiZ0lAllkP0d7ZxcG20Iab7VcSqCZE=";
        "24.15.0" = "sha256-pPZT157RQKqtkh6MIqO1hcqFz9q4DUAw9jCeRmOoocg=";
        "24.16.0" = "sha256-L/hKbecLYWUpARGw/GVt7RrSB6eZgW/nIMx8MSMt8w8=";
        "24.17.0" = "sha256-p6tWLtI2minGi3L6AOMQO83+NwY9/3mcasyOQE4nX80=";
        "24.18.0" = "sha256-6Ur94k2wjgxWTucRCi1aq1HuAFk4LJ/YIzxU7sR7KPk=";
        "24.18.1" = "sha256-htQNWUu9/PaQCaYv30PLGa5ytstYItK92DScWhsvpig=";
        "24.19.0" = "sha256-9tleEKBDHuEGf8aqvp92KQi0cW3TUyTh3bSxRmt2ZZ8=";
        "24.20.0" = "sha256-JzL8P1iN0zXNZ3nAaGT3zUJLsbX/mhdDBZpmxU+cpKE=";
        "24.21.0" = "sha256-pvVN77b9fIT0HboT1h546bTglhcSz2HylxXAX1ztlPw=";
        "24.22.0" = "sha256-Qfl8/yxmbx+Ck9xfhcZejdYFwWtD/Z/r1J7eMu4eAyk=";
        "24.22.1" = "sha256-T1N5eWKAza6wwvNY/QS2oWzE+336g7WoyRqdljtDUjE=";
        "24.22.2" = "sha256-j+LsFyO7n40LaDkHyCcI3rvtpkryHLKqIUxCQe7QoGE=";
        "24.22.3" = "sha256-SMo6qKmwITM1aSLvT8gCAOAFmMgKTvRG98OaRZIiWT0=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Upstream configure accepts Python 3.14 and rejects Python 3.15.
          python = tvp.packages.python_3_14;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          # OpenSSL 4 makes the ASN.1 types used by ncrypto opaque.
          openssl = tvp.packages.openssl_3_5;
          zlib = tvp.packages.zlib_1;
        };
        # Upstream defaults to Temporal off; the opt-in V8 build fails in this era.
        opts.temporal = false;
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "25.0.0" = "sha256-KCLNe1EMlV+MTUSPpIPwHSg5JRd0Igo1amubwqsgOa4=";
        "25.1.0" = "sha256-7ndBGQ5HQC38YhVHrCPT9Y5kY6hoeNwYefuejeHOMiY=";
        "25.2.0" = "sha256-i/e6+1qJ09IO77yxWUAeKrzOoM+FvvZeMUtiZzDFJaE=";
        "25.2.1" = "sha256-qnxKwQdtwpmolJuNg0JjZZskCOwOW7pIRnOozgdmyLk=";
        "25.3.0" = "sha256-l5OQme3QNaDBotH8hJysAY7Co4wMKN2Ogkb9iDzbnp4=";
        "25.4.0" = "sha256-BONlqtzXv0zxpgAXI+pBA1v7EY14+KjuIFSzf8XLZ9Y=";
        "25.5.0" = "sha256-fjXvr2PI/nc3uMYnkuxUflqVpp8fgT/PuihWauzJ/ZI=";
        "25.6.0" = "sha256-nbaEjIArGYHA+utxpbjMeZE/gqdH9/HVAmDG0veB734=";
        "25.6.1" = "sha256-z3Vngci03F7gMPh9351RuNW/IZrVbL2YVcSjvcgyx44=";
        "25.7.0" = "sha256-jxPffo95w+jyJ61xPHVFkik8mPcOnino/O6XTmKgAOE=";
        "25.8.0" = "sha256-XQBCnLhWzHIgDsbAjozdp16pYYJW3o2Jn6BJwj9KLu4=";
        "25.8.1" = "sha256-CyWytfq4Dqi0P9qnRR9QBlVx4L/aJSTKQr3ouY/k0tk=";
        "25.8.2" = "sha256-PvsZ51fcWbshYyUHIA0t54I2nVImpolV6Tcskl/fJHE=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Upstream configure accepts Python 3.14 and rejects Python 3.15.
          python = tvp.packages.python_3_14;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
        # This release defaults to Temporal off; the opt-in V8 build fails.
        opts.temporal = false;
      };
      releases = {
        "25.9.0" = "sha256-j3ivPuVfsnhmi1+AHbWL0aOOoWExjrXOISjdvJzYE6o=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Upstream configure accepts Python 3.14 and rejects Python 3.15.
          python = tvp.packages.python_3_14;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "26.0.0" = "sha256-/LXlwGpcLsnmaYASSGV6r6oikfh2Dax7+2Ofh4MYxZI=";
        "26.1.0" = "sha256-d5oTZIiVddROAhWtw4GAa70NlDdVe1mJPhcvW501qZA=";
        "26.2.0" = "sha256-6oK+fbQY9Us+8VOgLUTU9nSEZvR2WugLxITzSvQN9hA=";
        "26.3.0" = "sha256-MZrV19IMxiLlXrdbnxolRrd6CL1GK2cDDQyJMWwsI0k=";
        "26.3.1" = "sha256-l5ubgwio0tSifGYu1QRIyF+XDA/U9c6LmOjaeMRB8rw=";
        "26.4.0" = "sha256-ns6zYhAkBp2RA1tUcdLr6GqgTSLb66cqeC6vNv+Rg6w=";
        "26.5.0" = "sha256-DheUcAl+JHoMB2m3fME1n8PhuvBobfibr+H7SMsYh/Q=";
        "26.5.1" = "sha256-33dwqamTRvi3O6bTGtib1vhotRxzh8NifctEygZfSUg=";
        "26.6.0" = "sha256-7LbuyBJQXJKSUpCHokNuxsiR/+DjqJeDNBbl10NtZZ8=";
        "26.7.0" = "sha256-5rGCy+6rAy0QgspKxP4V46V95pHTveeOz4p2H9Vu41Y=";
        "26.8.1" = "sha256-0WmIMqGhDwUM3aBEo+PWp0gkaBHi57yJupqL1pPcRfI=";
        "26.8.2" = "sha256-NrN79e5NCSudnf8tGpCxRE+LRT7d9v+Wyr3ruX0y9B0=";
        "26.9.0" = "sha256-R7lw2IURtCnlh7dA+nMxdpCdKiAFopZi8BsFIF9YRos=";
        "26.10.0" = "sha256-ezpUbTPLfhWkO916V+C+XV/V/8VT5uTBIAM+ZvC6IMU=";
        "26.11.0" = "sha256-qq2SQnBFJBCeiNSL57t7eUNIbZMedAo1LALpfhB/GMk=";
        "26.11.1" = "sha256-LHmjwQlcfaTFSchOkLLSjfVHkxWrbQr/m8cdz0yd8eA=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          # Upstream configure accepts Python 3.14 and rejects Python 3.15.
          python = tvp.packages.python_3_14;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
          {
            file = ./patches/release-tag-26.8.0.patch;
            reason = "Match the published stable release by removing its stale alpha macros, as in 26.8.1.";
          }
        ];
      };
      releases = {
        "26.8.0" = "sha256-IodhPKpx+auN/0y+x9oy8Prj6IB6aHand2SswW1Mykw=";
      };
    }
    {
      def = {
        builder = ./build-owned-22.0.0.nix;
        deps = {
          # GYP's Ninja generator imports ctypes; the base's small helper Python
          # deliberately omits it. Keep this requirement local to Node.
          python = tvp.packages.python_3;
          # Exact previous runtime shell; independent of public Bash's bashbug.
          runtimeBash = tvp.lib.packages.withConstraint {
            category = "construction";
            reason = "Retained source-GNU Bash provides the existing compiler-free Node subprocess/npm shell.";
          } tvp.bases.gcc_16.full.shell;
          rustc = tvp.packages.rustc_1;
          cargo = tvp.packages.cargo-bootstrap_1;
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
        };
        patches = [
          {
            file = ./patches/store-shell.patch;
            reason = "Bind subprocess and npm shells to the explicitly selected Bash.";
          }
        ];
      };
      releases = {
        "26.12.0" = "sha256-zln5A43aDmN2VvscNs9SwHxjeSL9gdQZ27ouwSmvvTU=";
        "26.12.1" = "sha256-BT47KWhZttjZP5nvl/qc7BxO4XHHKWgQDGSZeMHb04w=";
        "26.13.0" = "sha256-Jj9jns+noXtJQ412zb+a/3MXnjx8t4naabkAcYQn+i4=";
        "26.13.1" = "sha256-p/YgT/Y7aizSdNSJAyhau4btU6mQcOUy1ML9eHRX2eY=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url = version: "https://nodejs.org/dist/v${version}/node-v${version}.tar.xz";
      discovery = {
        type = "json-index";
        url = "https://nodejs.org/dist/index.json";
        selector = ".[].version";
        normalise = tag: if pkgs.lib.hasPrefix "v" tag then pkgs.lib.removePrefix "v" tag else null;
        include = version: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" version != null;
      };
    };
    tests = (import ./tests/provider-context.nix { inherit pkgs; });
    testDeps.shell = tvp.packages.bash_5;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.nodejs = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
