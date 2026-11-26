{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-2.0.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
            } tvp.packages.openssl_1_0
          );
          readline = (
            tvp.lib.packages.withConstraint {
              reason = "Ruby 2.0 ext/readline casts to Function; readline 6.3 removed the obsolete typedef present in 6.2.";
            } tvp.packages.readline_6_2
          );
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
          libffi = tvp.packages.libffi_3;
        };
        opts = {
          cStandard = "gnu17";
          mkmfProbeFlags = [ "-Wno-error=implicit-function-declaration" ];
        };
      };
      releases = {
        "2.0.0-p0" = "sha256-r/hbpc63AwPLf7YW9duLlexHqIIBFhmNHIZsxP/xUe0=";
        "2.0.0-p195" = "sha256-ov6NROrDwn0ZHKLQ7i2HH5rthzx0SRsqjfIpv9xOWpM=";
        "2.0.0-p247" = "sha256-PnEEKHLHdyZAlGDoZHovMECDoVrg3v6Q2AAKaZF+INM=";
        "2.0.0-p353" = "sha256-Rlr8d9IBtYFbt842YKH1oTH0Qpo/pIPBJs5mkj5HJsw=";
        "2.0.0-p451" = "sha256-5taQDrQIQFMFg0nP2/Y60UFLao111YtH7YEBCplH5zs=";
        "2.0.0-p481" = "sha256-AN09ckNet38r2UU3wXOOUhnKQrbWjfPU8gwYP0vRLQ8=";
        "2.0.0-p576" = "sha256-n1pZPYF2jIVhVb5rLS41e5YbXEPgS6VMHuURmH+sK2Y=";
        "2.0.0-p594" = "sha256-7lFd17F828EGOWzUMvVmK7C1r8BQREaRdZFKq2Xzxuc=";
        "2.0.0-p598" = "sha256-QTa/fXZMvMHH2igk7Sgmw1UPK2KvZzx53b+QSbEglf0=";
        "2.0.0-p643" = "sha256-S9JnpBh+S8JcHbCPn5vcDOWVpwVWnKxGDZjE9bAuYU4=";
        "2.0.0-p645" = "sha256-Xp+O///pfLpe8AFf7sbh5fO6z2rOeM0c33JwjNcc9Ks=";
        "2.0.0-p647" = "sha256-yIqvW07HLiy30pD/hU8E0TWTn2E09RcAKp1l1fxeW+w=";
        "2.0.0-p648" = "sha256-hpC9a0lJwzOzkZdVxOSIhdv+1v0FX+nviZML3g0jdvg=";
        "2.1.0" = "sha256-NTjsH2r5btnesE4JZSdFKBYnJsybo2JdzyNkjfhy0J0=";
        "2.1.1" = "sha256-yEPfMa6I7Un1OTFCsCuan1plV0U4Bf1Imnb7r+roiUE=";
      };
    }
    {
      def = {
        builder = ./build-2.0.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
            } tvp.packages.openssl_1_0
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
          libffi = tvp.packages.libffi_3;
        };
        opts = {
          cStandard = "gnu17";
          mkmfProbeFlags = [ "-Wno-error=implicit-function-declaration" ];
        };
      };
      releases = {
        "2.1.2" = "sha256-8ipkR4EagfPICNHCpc47X18JVcaMmnSRgv60JVieZjU=";
        "2.1.3" = "sha256-CBi+t7EM6aBYzSHYXP4dzSM+mLc0LTLppdS+vpg0fwE=";
        "2.1.4" = "sha256-v5lSzes6DGpaJ3Rcm0wOXiZOkrZpsrCO+zY/UVZUkgQ=";
        "2.1.5" = "sha256-QwXMbOsJTfVSENg1SNy+tRF9dO6iUZapsU+iaNNUsQA=";
        "2.1.6" = "sha256-HhNirnQnyR+lPcnAWu5O4gDi19iXCokcW9dr7ijSi+Q=";
        "2.1.7" = "sha256-9ZwVlqw5zH5gEm59NpjBn0gvBAYGdP3+ASThdSum3YE=";
        "2.1.8" = "sha256-r9gyuNXssuPhR37GqUCP35iY7nPkxd8XorLLNr0cNV0=";
        "2.1.9" = "sha256-A0y5xQZ20sCbO2z1yAA1hazqBQCNmin6c3xU1Swetww=";
        "2.1.10" = "sha256-+y5FTXpeWjnrVNsOxmb1Putu3Fk9HSuXCuTRULgx3SA=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
            } tvp.packages.openssl_1_0
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
          mkmfProbeFlags = [ "-Wno-error=implicit-function-declaration" ];
        };
      };
      releases = {
        "2.2.0" = "sha256-dnHjlKv7XSYvvNOyenG/eHN8fpNH+iHDnliwu5xIQPw=";
        "2.2.1" = "sha256-Wk3jgGjsqJGcsIfTOMDC49csk4LIBPsnq3RubHgZqyg=";
        "2.2.2" = "sha256-X/wPMX5Cnmsp1KmKxSHDzmVIG/0iqM+EX6AqexE9m0Q=";
        "2.2.3" = "sha256-33lfL5mGB0WkFgkqQASwFsz3fouC3slWsSDxi9xx7c4=";
        "2.2.4" = "sha256-tu/1aLSOD9p25aNjMxdd8EmyBOkSF6oyplFTzAzct2E=";
        "2.2.5" = "sha256-MMSzFpekyk6gyNuK0wz0XmaQoPCWh+XUg8kzwDyjNeM=";
        "2.2.6" = "sha256-3o4ZJ5HLFX1hDEipqf9ufxnWfOhgUv6uYrguNoLMZ18=";
        "2.2.7" = "sha256-N0GExsW7yI+3utQiNo1AU6I2+2WH8O/3YUbculf5PaU=";
        "2.2.8" = "sha256-jze52FOL+OUK0JjbKnFupJWFrRYBu9NH74TKBmLZJoo=";
        "2.2.9" = "sha256-L0fHcFT8QMz94iUBQlJW0yxPoMyvlVTw1pntQ2vsoaY=";
        "2.2.10" = "sha256-zVEBnrnZx4bWyxeMN/aBLYpB1pFKHtrwBQwFHHXXw1g=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "2.4.0" = "sha256-FS/QvRWpC0oYITRI9IXUtT6fdmLhUIGQqltwJEaynj0=";
        "2.4.1" = "sha256-ozDhDVy15Ts6AHgybFcxiIu1XjLEq/6yfZ5/jl0AAlA=";
        "2.4.2" = "sha256-k7nnXgCyYrxN72smt66HF+/CUsRxVKu3OS5UNX5sjJw=";
        "2.4.3" = "sha256-/QN1WCySBFqn0xhU5yRHH7Rp4RpLCP8zTTkFLMqqOpg=";
        "2.4.4" = "sha256-JU8cGnnkzIFNHnMgvFvdmV3FfghyfTCnZ2ZGGanIrlo=";
        "2.4.5" = "sha256-Zzd0Gub/phF0yKPc3YupK8OIJ4J6sdfqHseLw878UZg=";
        "2.4.6" = "sha256-3g3ICXAjcWCZ98im/8dRURuQ3n9WlPQBtZ8tBx25EL4=";
        "2.4.7" = "sha256-zW78cgympiJ0XiusefRebNY6sPWlOtfriBVF9Y/zi4k=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
        patches = [
          {
            file = ./patches/rbinstall-gem-dir-umask.patch;
            reason = "2.4.8's tarball ships its bundled gems only as .gem files, and the .gem path creates each gem directory under rbinstall's own umask of 0222, so the first file written into it fails with EACCES. Every other 2.4 release also ships them unpacked and takes a path that chmods the directory itself.";
          }
        ];
      };
      releases = {
        "2.4.8" = "sha256-N/DRgK+lbsPno2acbxtu6KR6gRJh8OGvqPgXyLV3vWg=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "2.4.9" = "sha256-+ZtrXjqlPVeaSetxndDTg01ZEkFZptQ1HR4DkVaxxq4=";
        "2.4.10" = "sha256-k9BnEXlb+3bb5+dl6Czf89352C7/Kh8k3q2btQbq8tA=";
        "2.5.0" = "sha256-RubzYw8YiOtlOxX6gR13tbHfb9ejr0NrNDz+T0UD8qs=";
        "2.5.1" = "sha256-2sgYIjJbecO6lTKwSMISM1fTMQsrQAJCAvNgJR2YKbE=";
      };
    }
    {
      def = {
        builder = ./build-2.6.0.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "2.6.0" = "sha256-88NbkkoRyI/xEfCVbe083BLJDAS3KyZqxhB202l/wHI=";
        "2.6.1" = "sha256-FwJPt7sgPZz3paQseP9s53FA+dCDZ2BEp9tn8eUZHLg=";
        "2.6.2" = "sha256-oEBdK/LC0vMyAztw3/NU0iSoZKsO3UYrekE0IEU7Sas=";
        "2.6.3" = "sha256-V3/TeV8iuNkcHU5nM2N7A5TUCC22WfzPIkx3Siscgvs=";
        "2.6.4" = "sha256-T8HYunVQWzeXAgpv/IWovP9q3E2rrjQ7ZXK/KB7heTc=";
        "2.6.5" = "sha256-ZpdrcW7MH9NPm3w8Kwe703YxgVN3ouPoWlsZTP3L7X0=";
        "2.6.6" = "sha256-NksUPe82C6wbdOtW7WCxoNymQ5sAFXrhH/d9XNLpIpE=";
        "2.6.8" = "sha256-GAe3hXe8CFlqOQ6KQa7eN7hRIZDgXBM7F9BQF5Goym0=";
        "2.6.9" = "sha256-63uueqxkv56yFTcQpMr65FDMu2Kub2PVc+F4YXiw77s=";
        "2.6.10" = "sha256-DcYJ8mPUnEF21XJd7vwzcnNnY5WYW14Bd4k3Poyt8W4=";
      };
    }
    {
      def = {
        builder = ./build-2.6.0.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
          compileFlags = [ "-Wno-error=implicit-function-declaration" ];
        };
      };
      releases = {
        "2.6.7" = "sha256-5CJ+i39lSF7Lczl6g+DQnc058l79QRx4K2lCTlXHqZ4=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
          restoreConfigScripts = true;
        };
      };
      releases = {
        "2.5.2" = "sha256-syNA5koMfsvzFIbEH+QppVx5hNmA7KengTg2fZIJ9HE=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "2.5.3" = "sha256-mCjQOFLDfCD6MzoCZPJJDwczhXZzTZEO4/1TjJUghGw=";
        "2.5.4" = "sha256-DkBCvOdJNS388bnjATunwHi3KPUfitr2RwzjdnXjyx8=";
        "2.5.5" = "sha256-KKlF/fNA5roE/IkLmGSDQuPMz9bSI6SPOBBXLxGyUUw=";
        "2.5.6" = "sha256-HX7QbGcwIM0SpzftaGRwVS6Omdcrgs08JtqjEVw2vqc=";
        "2.5.7" = "sha256-Cy0NXjRRtqtFT4Gxv8oAdAfAVI3qQD8eui5CnaSt1tQ=";
        "2.5.8" = "sha256-bAvfB4dsaYEann3CN8Q9QLHLY2n2jg4XlT1yebUkrZo=";
        "2.5.9" = "sha256-9YlOBfUyt0jDNHiUpe+kIGb9EcyNJh1Nl4j/cdoAvmg=";
        "2.7.0" = "sha256-jJmqk7Xi8byEN9G7vv0nsT52lAJTMfdyRdDAaO8fjL4=";
        "2.7.1" = "sha256-1BhIO90AAFdsE3BXESGm6yRYIRbbC3uyAF6Q4lDq5Bg=";
        "2.7.2" = "sha256-blcG0NTuTh4viD2512hYa00GVn3r6jU8eW7EXoMhw9Q=";
        "2.7.3" = "sha256-iSWpXjHY8sgXSQJaUqVE6h0F2tGHlOaChwkmi5LlUzg=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Consumer reaches OpenSSL structures made opaque in 1.1; use the 1.0 API line.";
            } tvp.packages.openssl_1_0
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "2.3.0" = "sha256-ulumDl8aohtO+Om/NbndtXKGy1RqrEtaKMcfRZRn5Qc=";
        "2.3.1" = "sha256-uHxzjLIDK/SSD++OOGTcXPjq6didjVI84CNpRcV5fc0=";
        "2.3.2" = "sha256-jX9soPFtd+PSQrJNo4mFt1OfWNwNoXfsYzqD0Mj1sZc=";
        "2.3.3" = "sha256-JBQIyMVVsliEY2iDCgYUbkhJodWNyvaxSjtqcwWBFbc=";
        "2.3.4" = "sha256-mOGPF8kzMY0OMv7TrqZ+ME8XTQMXCjj9kgxPvkn+wMM=";
        "2.3.5" = "sha256-VGL3u7KL7/XadEGWhHHtki+WTbGr3OgriGBgiswj3cw=";
        "2.3.6" = "sha256-gyJRMnn57fphLURbwRGoeJT6wRKOqlOTAc6/wN1RVx4=";
        "2.3.7" = "sha256-Nc00nN33jkoGQNKOyMfoiirg21Hr2JJs0jK7cNssfX8=";
        "2.3.8" = "sha256-tQFtYUQOk5BF1OIpeeBHCO1sjhxS5+2yVTz0C3PFmr8=";
      };
    }
    {
      def = {
        builder = ./build-2.7.4.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "2.7.4" = "sha256-MEMJkIlgiFn8jM5/n9zKofU6RiRX44OOw7JafWCfvFs=";
        "2.7.5" = "sha256-J1W5AKISNbRDuxba3ZAy94TUqI8UPYUrxdFU8iuHgfE=";
        "2.7.6" = "sha256-5yA7DMCUQu0sCJNtSD+KwUDsHHLje7XEAWRreGbLXRA=";
        "2.7.7" = "sha256-4QEn22kdf/NkAs/oj0GMjQJaPx7qkgRLFi3XLwuMe5A=";
        "2.7.8" = "sha256-wtq2PLyPKgVSYQitQZ76Y6Z+1AdNu8+fwrHKZky0W6A=";
      };
    }
    {
      def = {
        builder = ./build-2.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = (
            tvp.lib.packages.withConstraint {
              reason = "Bundled ext/openssl uses APIs incompatible with OpenSSL 3; retain the verified 1.1 API line.";
            } tvp.packages.openssl_1_1
          );
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          gdbm = tvp.packages.gdbm_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "3.0.0" = "sha256-oT7RQaHBjrlnqsHjP01q1fIb4axUPDRODW/u7lSvjig=";
        "3.0.1" = "sha256-Npgl2yGZ9q7vFrQI32oE663bZk+5rw7Ixoawznq3dyc=";
        "3.0.2" = "sha256-UIXe4K2fBplqis7H6+pKhzXm+sIvIuLZjD8rw7735vE=";
        "3.0.3" = "sha256-NYaGHLLfVpcCh/D9g/J0vZIFiHLYMNFVcLNt738akqw=";
        "3.0.4" = "sha256-cLR8IHrwS86azqJiMI+0KJPT4kTzmkq8WGkgoccjcis=";
        "3.0.5" = "sha256-mvxjgKAnpP4a4aPi7MtrSXucWsBjHBLKVvm3vrSEh3Y=";
        "3.0.6" = "sha256-bmy9SQAw15EMD/IO3vq0KU380QRvD49H94tZeYesaD4=";
        "3.0.7" = "sha256-KjQRl38oUEMRNrD6uK1Trwn7dN8u4vT7fxGzeP4DQ4g=";
      };
    }
    {
      def = {
        builder = ./build-3.1.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
        };
        opts = {
          cStandard = "gnu17";
          extraWarnFlags = [ "-Wno-old-style-definition" ];
        };
      };
      releases = {
        "3.1.0" = "sha256-UKBQTG7ctNYc5rjP292qlXBxlfqw7Ne16SZUsqlBKFQ=";
        "3.1.1" = "sha256-/m5Hgt6XRDl43bqLpL440iKqJNw+PwKmqOdwHA7rYZ0=";
        "3.1.2" = "sha256-YYQxEjifArc1QotTu2TPmIrZ+4GFi4JI4i5XM28kqD4=";
      };
    }
    {
      def = {
        builder = ./build-3.1.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "3.1.3" = "sha256-XqSYo19M0Vh1IApS3eQrbrF54SZOF9eHMsOlfNHGq54=";
        "3.1.4" = "sha256-o9VYeaDfqx1xQf3xDSKgfb+OXNxEFdob3gYSfVzDx7Y=";
        "3.1.5" = "sha256-NoXFHu7hNSwx6gOXBtcZdvU9AKttdzEt5qoauvXNosU=";
        "3.1.6" = "sha256-DQ2vuFnnZ2NDJXGjEJ0VN9l2JmvjCDRFZR3Gje7SXCI=";
        "3.1.7" = "sha256-BVas1p8UHdrOA/pd2NdufqDY9SMu3wEkKVebzaqzDns=";
      };
    }
    {
      def = {
        builder = ./build-3.2.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          readline = tvp.packages.readline_8;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "3.2.0" = "sha256-2qp44TYLJ4P5je7OtnetkA86NsD/puK2sZCQvnerwnI=";
        "3.2.1" = "sha256-E9Z5AWYO4yF9vZ3VYFk0a9QhLOZKacMG71LfZJNfjb0=";
        "3.2.2" = "sha256-lsV1WIcaZ0jeW8nydOk/S1qtBs2PN776Do2U57ikI7w=";
        "3.2.3" = "sha256-r38XV9ndtjA0WYgTkhHx/VcP9bqDDe8cx8Rorptlybo=";
        "3.2.4" = "sha256-xys8XDBILcoYsPhoyQdfP0fYFo6vYm1OaCzltZyFhpI=";
        "3.2.5" = "sha256-7wYQtJj2D7XP13tRrbPBD0yo7ZoXy4fGHlvqMUrDShY=";
        "3.2.6" = "sha256-2ctl7N8/GGaWOfJji2M3ntb7sX2Trk5ybU6yv2ikg3A=";
        "3.2.7" = "sha256-hIj6Yg/wMzwW1DfyuJC7o7Z/h0X97LFHJWimEUqtl0E=";
        "3.2.8" = "sha256-d6zdjPu+H45XO15lNuA8UQPfmJ3AX6aMcPARgzw1YHU=";
        "3.2.9" = "sha256-q7rZjbmusVJ3Ow01ho5QADuMRn89BhUld8Tf7Z2I7So=";
        "3.2.10" = "sha256-iArLBeCNqMVZxWoT5RK64bRy2mfHLrt1DHZfnCE05ok=";
        "3.2.11" = "sha256-s+6r1mNvM0Ux2z/9wyKesF5SR0DmyE/cBDcgVzzy+LI=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "3.3.0" = "sha256-llGIFNmDK+zpKoVBWoGdSJOzB9tZIa4fD3Uamomla30=";
        "3.3.1" = "sha256-jcKvKALMcAzRgtVDByY4jM+IWz8KFPzWoPIf8knJqpk=";
        "3.3.2" = "sha256-O+HRAOvyoM5gws2NIs2dtNZLPgShlDvixP97Ug8ry1s=";
        "3.3.3" = "sha256-g8BbIXfunDNbYxspuMB3tHcBZtAvpSfzqfakDRPzzOI=";
        "3.3.4" = "sha256-/mow+X1U4Cl2jy3fSSNpnEFs28Om6W2z4tVxbH25ajQ=";
        "3.3.5" = "sha256-N4GjUEIiwvJstLnrnBoS2/SUTTZs4kqf+M+Z7LznUZY=";
        "3.3.6" = "sha256-jcSP/68nD4bxAZBT8o5R5NpMzjKjZ2CgYDqa7mfX/Y0=";
        "3.3.7" = "sha256-nDfDsSKIx67CDKEhznaEW+W7XXdmKiSRllGq8dEshig=";
        "3.3.8" = "sha256-WuKKh6WaPkrWa8KTHSMturlT0KqPa687xPj4CXfInKs=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
        opts = {
          cStandard = "gnu17";
          libDir = "3.4.0+1";
        };
      };
      releases = {
        "3.4.0" = "sha256-BoyFI0QhdL00AOeG9KaVI1LIKxufYhD9F/tIIwhtM3k=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
        opts = {
          cStandard = "gnu17";
        };
      };
      releases = {
        "3.4.1" = "sha256-PTheXSLTaLBkyBehPtjjzD9xp3BdftG654ATwzqnyH8=";
        "3.4.2" = "sha256-QTKKwh8r/dfeazVl708N11QzVNN+lvFXoVUqa9DrNks=";
        "3.4.3" = "sha256-VaTNHcvlyifPZeiak1pILCuyKEgyk5JmVRwOxotDf0Y=";
        "3.4.4" = "sha256-oFl7/fMS4BDv0e/6qNfx14MxRv3BeVDKqBWP+j3L+oU=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
      };
      releases = {
        "3.3.9" = "sha256-0ZkWkKThcjPsazx4RMHhJFwK3OPgDXE1UdBFhGe3J7E=";
        "3.3.10" = "sha256-tVW6pGejBs/I5sbtJNDSeyfpob7R2R2VUJhZ6saw6Sg=";
        "3.3.11" = "sha256-WfD6+xpZoF3DdlEXrz+mjhU+tIJUcIVJ8yHB6eB416A=";
        "3.4.5" = "sha256-HYjYontEL93kqgbcmehrC78LKIlj2EMxEt1frHmP1e4=";
        "3.4.6" = "sha256-48Gauej0GzcjEk+8ARTN58v1XmWqnFjBKs2J7JwN0bk=";
        "3.4.7" = "sha256-I4FabQlWlveRkJD9w+L5RZssg9VyJLLkRs4fX3Mz7zY=";
        "3.4.8" = "sha256-U8TdrUH7thifH17g21elHVS9H4f4dVs9aGBBVqNbBFs=";
        "3.4.9" = "sha256-e7TU9egHzCclHRTZ1ghtGCxbJYdRkeRKsVtwnNen3Zw=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
      };
      releases = {
        "3.3.12" = "sha256-sG1jvq4nGTMDPifwo4m8WCoAnnhFNX1ENlw53lJaBRs=";
      };
    }
    {
      def = {
        builder = ./build-3.3.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          inherit (tvp.packages) openssl libyaml;
          zlib = tvp.packages.zlib_1;
          libffi = tvp.packages.libffi_3;
          rustc = tvp.packages.rustc_1;
        };
        opts.nativeControls = true;
      };
      releases = {
        "3.4.10" = "sha256-7O4tByoU8tFDR91W39j+XDEwq/URe/qsvaD075zEKew=";
      };
    }
    {
      def = {
        builder = ./build-4.0.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          openssl = tvp.packages.openssl_3;
          zlib = tvp.packages.zlib_1;
          libyaml = tvp.packages.libyaml;
          libffi = tvp.packages.libffi_3;
          rustc = (
            tvp.lib.packages.withConstraint {
              category = "construction";
              reason = "Exact Rust distribution for the named Ruby source profile.";
            } tvp.packages.rustc_1_97_1
          );
        };
      };
      releases = {
        "4.0.0" = "sha256-LoOJyMByy2WMk6E3JzLZ6shAgsiLBldQ2x5SpaxjAnE=";
        "4.0.1" = "sha256-OSS+LQXbMPTjX4Wb8Ci+hfS33QFxQUL9gj5K9d4vr50=";
        "4.0.2" = "sha256-UVArJrULaN9JYzNspB42jN6SySj6+RZU3kxMF5H4Kqw=";
        "4.0.3" = "sha256-d5ZKzDcNXIN1uVAuW6bBPAPvkaueufUhyE+0K5yaaw8=";
        "4.0.4" = "sha256-819u36Pauz9yP50M8ZBsZRKud/TkEqseaMxukdIw+oA=";
        "4.0.5" = "sha256-fWFJB5pj+K4dMmyfplxgGbotwxVerns5FZgXkRyIlY4=";
      };
    }
    {
      def = {
        builder = ./build-4.0.nix;
        dependencyNames = s: builtins.attrNames s.dependencyProviders;
        deps = {
          inherit (tvp.packages) openssl libyaml;
          zlib = tvp.packages.zlib_1;
          libffi = tvp.packages.libffi_3;
          rustc = tvp.packages.rustc_1;
        };
        opts.nativeControls = true;
      };
      releases = {
        "4.0.6" = "sha256-g30pno993yvjGiKaen4BnTVJeYJRF5iayzsysam+Jio=";
      };
    }
  ];
  pname = "ruby";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.security = {
      schema = 1;
      purl = "pkg:generic/ruby";
      cpe = {
        vendor = "ruby-lang";
        product = "ruby";
      };
    };

    testDeps.consumerCompiler = tvp.lib.packages.withConstraint {
      category = "artifact";
      kind = "exact";
      namespace = "bases";
      selector = "gcc_13_3_0.full.compiler";
      reason = "Independent GCC 13 consumer control against Ruby built by GCC 16; preserves cross-compiler extension coverage, not a compatibility limit.";
    } tvp.bases.gcc_13_3_0.full.compiler;
    source = tvp.lib.sources.archive {
      url =
        version:
        "https://cache.ruby-lang.org/pub/ruby/${pkgs.lib.versions.majorMinor version}/ruby-${version}.tar.gz";
      discovery = {
        # One TSV listing every tarball back to 0.49, rather than one request per
        # minor directory. It also carries each sha256.
        type = "directory-index";
        url = "https://cache.ruby-lang.org/pub/ruby/index.txt";
        pattern = "ruby-[0-9][^[:space:]]*\\.tar\\.gz";

        normalise = tvp.lib.versions.fromArchiveName {
          prefix = "ruby-";
          suffixes = [ ".tar.gz" ];
        };

        # Patchlevel tarballs (1.8.7-p374) are real releases and stay.
        include =
          version:
          !(
            pkgs.lib.hasInfix "preview" version
            || pkgs.lib.hasInfix "-rc" version
            || pkgs.lib.hasInfix "beta" version
          );
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
  variants = tvp.lib.packages.mkVariants (
    family
    // {
      inherit pkgs;
      profiles.build-steps = {
        base = tvp.bases.gcc_16.full;
        versions."4.0.6".deps.rustc = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "Exact Rust distribution for the named Ruby source profile.";
        } tvp.packages.rustc_1_97_1;
      };
    }
  );
in
{
  recipes.ruby = family;
  inherit canonical variants;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
