{ pkgs, tvp }:
let
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.9.7.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts.cStandard = "gnu17";
        patches = [
          {
            file = ./ordinary/0.9.7-build-order.patch;
            reason = "The original recursive crypto and SSL targets start shared linking before their archive writers finish.";
          }
        ];
      };
      releases = {
        "0.9.7" = "sha256-CoBRPltBb69HBMbi2/3hG0gmlHm+QX8JIKooNg0lkQA=";
        "0.9.7a" = "sha256-1cVx3PPCLCrKa50tL5oILmDgfu45eqNFIxgXfR9QlaI=";
        "0.9.7b" = "sha256-LhniMMNuwXJzavdugx+aYYaAnDYzVXSPTlFAahEvCDE=";
        "0.9.7c" = "sha256-wLjHD9Z3xIGwL7nXsCDqVJZrf5tOmwtrK+fpAFLlZQY=";
      };
    }
    {
      def = {
        builder = ./build-0.9.7.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts.cStandard = "gnu17";
      };
      releases = {
        "0.9.7d" = "sha256-Bf39B+iBz+tYTneRnt3HTaw/laziOsvqAIwq+Ut2wUc=";
        "0.9.7e" = "sha256-JRIbXb0rgwkpUZMl4DMIbORYYc/y0AANko9IJhseC3w=";
        "0.9.7f" = "sha256-Nn2z7nXmMySyCQB0sSqBcCGLps7ziydWOQ0IlBwWJgg=";
        "0.9.7g" = "sha256-5+GihxQd0b5/S0/t1U7Cn6kEZV7XahOsh65po/x2sGI=";
        "0.9.7h" = "sha256-tjjDhTEtK9ao8BdsJgW9YTyXjlVdPS14AnDhYIfyDeE=";
        "0.9.7i" = "sha256-L92SNfwIxDU4ddCYF0GUfy+p+INfBNl8MEYcwUqYbdA=";
        "0.9.7j" = "sha256-ZabojDOXy2jRnbtXbs+fnY3EFCOqmsMCXNKeOYcnRGA=";
        "0.9.7k" = "sha256-m7znXVXAP61H98peZ5D6zKSyA7KMbDNCjRpHHvc+5iI=";
        "0.9.7l" = "sha256-ftGYWckuHBPp+O1cPeNcPUjkW/8bUv/EOEXMDIVvo9E=";
        "0.9.7m" = "sha256-yYuXA4h+LdpiF7kUBdDZSIP3xn4gX8TXqBu2kNLhBXI=";
      };
    }
    {
      def = {
        builder = ./build-0.9.7.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          hardeningDisable = [ "format" ];
          installedInterface = {
            sha256 = true;
            pbkdf2 = false;
            providers = false;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = false;
            modernCli = false;
            cmake = false;
          };
        };
        patches = [
          {
            file = ./ordinary/0.9.8-build-order.patch;
            reason = "Before 0.9.8j, the archive submakes re-enter top-level shared linking. Separate the archive and shared targets and order writers to libcrypto.a.";
          }
        ];
      };
      releases = {
        "0.9.8" = "sha256-wRVLimpFFodA7MnzjUbfrUDrJ65Rq9doM6GNTJpktR0=";
        "0.9.8a" = "sha256-MPj2H7Exb0+1FBDHQLSHm44mtBfI2HDkhhRLELgEHHM=";
        "0.9.8b" = "sha256-ae/tYnWUL5MS3mHPaarvErBsEvaxDzGWcs4CanVvZcA=";
        "0.9.8c" = "sha256-iW94MMGSFojyLG/k+z17dRic7915rMpfsMrStZkTkEg=";
        "0.9.8d" = "sha256-AiGUlEzCDa2RfIbJFtuKTgBQ3y3pG5tnQN3U+y2vF10=";
        "0.9.8e" = "sha256-QU6EKLlfvFFweWX9oxOQSX0FgpA1ZCa/4IS0lGSmA0A=";
        "0.9.8f" = "sha256-vlr9OG9des/wGayvRs2q2JqLQsyc7oXRrbJ3RifzK0I=";
        "0.9.8g" = "sha256-DiaIaEXelXFsnxubdcDgbp1AddK9yeEVBOql9+6QHPA=";
        "0.9.8h" = "sha256-Ik4co67tqKzHLlxIs0hDkEudWFqq201aFVJMJfbGoc4=";
        "0.9.8i" = "sha256-6Pxfz7cV/+klspgqqcooeDKpNJXX//A/F/ZEnwcycYw=";
      };
    }
    {
      def = {
        builder = ./build-0.9.7.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          hardeningDisable = [ "format" ];
          installedInterface = {
            sha256 = true;
            pbkdf2 = false;
            providers = false;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = false;
            modernCli = false;
            cmake = false;
          };
        };
      };
      releases = {
        "0.9.8j" = "sha256-cTEkIELb1jH72DQ29CrqF3Xnwy9Yf6StpaAd9MOujos=";
      };
    }
    {
      def = {
        builder = ./build-0.9.7.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          installedInterface = {
            sha256 = true;
            pbkdf2 = false;
            providers = false;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = false;
            modernCli = false;
            cmake = false;
          };
        };
      };
      releases = {
        "0.9.8k" = "sha256-fnzU85dBmbcp5uOgrwi9Qnn94DcKESDBo7NRqwkMYQE=";
        "0.9.8l" = "sha256-7NBU6e7S6cFiC6FSV+b8TYgsmkrqZj0jt2niE43oyRo=";
        "0.9.8m" = "sha256-NgNxYCgc9Jd9lk5APSvAaA+8oKf/n2XjMTbXX64Sy1s=";
        "0.9.8n" = "sha256-sBq8KDdrhmUV31jxsATahFMWYpF4PU50d82omwAMHwE=";
        "0.9.8o" = "sha256-vvraGsOBmx0xffgZe16C7HaLOdJQ/L74Hisct/Fl1Eg=";
        "0.9.8p" = "sha256-smReKiryIfojC172qiuTiKh1gBt0y927Fr5Vf4D0UkI=";
        "0.9.8q" = "sha256-1SKz6KK0joO6HhQtcgXqygE1ihN7tY6NZFg1dOaX/9c=";
        "0.9.8r" = "sha256-QrI2j3hrBe076EaDjc4Sa06OPbqPsuDOgxAt8owQL60=";
        "0.9.8t" = "sha256-a5s+9eqULXtcPOI+npKdjuzQkOgfGNh606ry65oiahQ=";
        "0.9.8u" = "sha256-BUjkuRcaYty76F5j2biXo13nGOD+GbP+VgAsj1o7pYc=";
        "0.9.8v" = "sha256-cBrE29J7kjeRmyFLU7wNCOXhRI8tD74cgEeSk9I3mmU=";
        "0.9.8w" = "sha256-U3QR/iz+JJqKW5iz+AmgftX5E7lKIWs8UQ/TUzGORZM=";
        "0.9.8x" = "sha256-fODH8sRRBwtEl+p8pvI+umzvGlbbLobkM/ZZJqe8dJc=";
        "0.9.8y" = "sha256-u+zxNJXmEpNuOphgwpwHAUE1ZLepZL93GjV16qhnzuM=";
        "0.9.8za" = "sha256-zcuY0PvAJsp5ixeRkzQxAnHTpZNVT/1qWWWbkiL9Tkg=";
        "0.9.8zb" = "sha256-lQ4imCN94WlxaN69QoYL9B6tYY4MA9yaOlbiMljkNb4=";
        "0.9.8zc" = "sha256-RhzGlPKecvWcIufqYb9EZxpfwviz/C7qyJcUt76RWIE=";
        "0.9.8zd" = "sha256-WSZtz7C+D75hge3q0ESsPtr4O8WJkfJk3PUysB1THuM=";
        "0.9.8ze" = "sha256-7j2mAoJul1tH5Neviie+gljBYIdhlImMWIgeq4FLVbg=";
        "0.9.8zf" = "sha256-1SRaKRKJhBkqzFsfwB43Qpt6AcU8rcsmReVGcYswDts=";
        "0.9.8zg" = "sha256-BlAAYGOZMORxBQR09Tf80o7JNK+S7igteLUkYPvo9YA=";
        "0.9.8zh" = "sha256-8dnz7RuFqC7PgNDi04nh/aP8qaTboL8Hrb8jHhpeL9Y=";
      };
    }
    {
      def = {
        builder = ./build-0.9.7.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          testCompileFlags = [ "-Wno-error=incompatible-pointer-types" ];
          installedInterface = {
            sha256 = true;
            pbkdf2 = false;
            providers = false;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = false;
            modernCli = false;
            cmake = false;
          };
        };
      };
      releases = {
        "0.9.8s" = "sha256-7cljm+ry1eI52OXJ0v4ZWeZyal1/irhDBhODX0Yj+bo=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          forceGccName = true;
          cStandard = "gnu17";
        };
        patches = [
          {
            file = ./ordinary/1.0-build-order.patch;
            reason = "Backport recursive build prerequisites from OpenSSL 1.0.1p and 1.0.2d.";
          }
        ];
      };
      releases = {
        "1.0.0b" = "sha256-TntOL7M+4tl8XhQ1YatJXbv8CPCoY+YXoMetyhkBczE=";
        "1.0.0c" = "sha256-9zGzbePtqjYRea5vRJZoskijYONOMekpAtl26bnWBOs=";
        "1.0.0d" = "sha256-klEdHwyqopjbolBCb459XQCycYR4htGtxiQid41jINs=";
        "1.0.0e" = "sha256-42HcJ3VzP7hN57W/e1BHeLdyhp6Pe/rAsouTXL9zgPc=";
        "1.0.0g" = "sha256-kFEGoVBefZ98Nu6BQI06o9QarCkalgPQwpDJUwyS/Cw=";
        "1.0.0h" = "sha256-fj38IapX7TPqZzFwBT0ZITIoA7impiSk8NLkwwi9QY0=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          forceGccName = true;
          cStandard = "gnu17";
          # The first two releases default to lib64 for a new x86_64 prefix.
          installLibraryDirectory = "lib";
        };
        patches = [
          {
            file = ./ordinary/1.0-build-order.patch;
            reason = "Backport recursive build prerequisites from OpenSSL 1.0.1p and 1.0.2d.";
          }
        ];
      };
      releases = {
        "1.0.0" = "sha256-G7+a/FpiFRIawJQUfQqEF4KU/kw9CiMXMQOP03F7p8o=";
        "1.0.0a" = "sha256-GKm9H8ArjvkN3tNPr6qQibqq/vJ4oZ/E6JwqsNz3D2M=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          forceGccName = true;
        };
        patches = [
          {
            file = ./ordinary/1.0-build-order.patch;
            reason = "Backport recursive build prerequisites from OpenSSL 1.0.1p and 1.0.2d.";
          }
        ];
      };
      releases = {
        "1.0.0i" = "sha256-VIJi0Vd3xQS+Grm7j6vvHhSj3lSDemWTyPQD3YQ9Xlc=";
        "1.0.0j" = "sha256-Ym+4/LPrfpZu2+cVU/+ZPRN/boqHsFBRo2leYhCYuK8=";
        "1.0.0k" = "sha256-KYKy6Wl6hXszbFwbG3tGN0flwdVg8l9qzpU2V5Gx79E=";
        "1.0.0l" = "sha256-KgcuZ9njrpAFSMQ9eTYwW6V2AlvQg9HpH/FNaN7R/ew=";
        "1.0.0m" = "sha256-Ik27+u461zN2ZeJOq1FsZ0RtUIE3mkCy9iPPeAHmct4=";
        "1.0.0n" = "sha256-OJXrWxwroHlAbQgTQNnh3AZPT79ND0HVPO/RVK3vKqI=";
        "1.0.0o" = "sha256-O29apPqlGQ8pZHzOaJmxRvWWhQPEGImAxDfKbxHYyP0=";
        "1.0.0p" = "sha256-t0XRHxlTFiCi50AhZ9VIRdJT8to+UjwtCVBZWu8QT8g=";
        "1.0.0q" = "sha256-Iw3BnqM7h4NsOIwRF6cfjrU5y/i+Qdk8O2yKauKd7Dk=";
        "1.0.0r" = "sha256-ZTizOhuVaByGrIxcxU0ig18PClv0LubfQTjGctfnXxc=";
        "1.0.0s" = "sha256-+4Ofdbm3GVoKrzB8oGS0NY7bloqVJMvfCp5W1jLyens=";
        "1.0.0t" = "sha256-WrbjSMbCqV1FfnoA4KplO/x+tN97JOfJq2MWOsApkJc=";
        "1.0.1a" = "sha256-00h+CdiRx3LPlGJzo7sMpHR555Qb5tgiJ0Mg58/MNhs=";
        "1.0.1b" = "sha256-EYe/LVzfCyhrlRv1x3eql4Vc19sk/blgTLVXyLHXNks=";
        "1.0.1c" = "sha256-Kp6zzU6LEU65F5wNOITWFljn2Oi/SYR5il9b1I4yXr4=";
        "1.0.1d" = "sha256-iKQj+bCKmUBUWDaRuWiBWHVYDhLfdU6IHXz+nxvR9J0=";
        "1.0.1e" = "sha256-908V6Mj/Eao9W7XydtIC7BjXJG6V+WHbdgVBmcacGuM=";
        "1.0.1f" = "sha256-bMKoCxfWTea3usmFdF/aupcdVP/X0401VvmY18DJy1o=";
        "1.0.1g" = "sha256-U8uBjDuQ5QeoNI9PXq7bBdi/5TWKq7UItyY8xnDD4Cg=";
        "1.0.1h" = "sha256-nRyKmDaqY+LGrbaEGGy9Q3HJ6dzAHW47tEer8tTT0JM=";
        "1.0.1i" = "sha256-PBefRsp3BppqC6xwISqbO4OLL2YSnLUtVog3/HnY/Mc=";
        "1.0.1j" = "sha256-G2DKh4m6bwPo7yDaIpO43BMcOdg4FOd1Bp8C0mNU7fM=";
        "1.0.1k" = "sha256-j5+urrrQiOdy9O9eOCUtRyvk2HjGs6JxjBCk/OvnpBw=";
        "1.0.1l" = "sha256-ss9NSP5dSfJAxhyeYkGTpvIyte0LrwEGgeclljxA0dQ=";
        "1.0.1m" = "sha256-CV8LewkRbAxVJkIgiAWNx+bgAKoU0irMpqTiurzf73Q=";
        "1.0.1n" = "sha256-NYGkBcy+D9H28X6kF3P3fN1R21XAHhtNhUnlGYgsbK8=";
        "1.0.1o" = "sha256-FuZ4xqBfJQKBHgdfLEBZrAHIeNCRycWFr8SevFQfexM=";
        "1.0.2" = "sha256-jEi687q+DVBdFs/AzyclicZtNiQmQJghPbD7AANHKOk=";
        "1.0.2a" = "sha256-FbY5PCADCqsCyOL+AkPLHR0YBi9sCV1nvKkYcdx/Mko=";
        "1.0.2b" = "sha256-1dSIzJ8KB5dBladCcJTqPKuYAKTpAXi5iapiH7wjjj8=";
        "1.0.2c" = "sha256-ADi6N/NaY2fFjxenp/aHlT74zk+WhLvexj5iUV7TaoM=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          forceGccName = true;
        };
      };
      releases = {
        "1.0.1p" = "sha256-vV7mgDFlwPtgu+y6ys8kTx+Q0qoNcTU69hDCkSHpsvE=";
        "1.0.1q" = "sha256-s2WLhOnqYGpd7TyXKlUXzXhSgufqhrIMeKpLdzoEf7c=";
        "1.0.1r" = "sha256-eEvY01XtAc6YuBL4c/iyMT2mHffHtWd/zy5XsIY6M0Y=";
        "1.0.1s" = "sha256-5+gdgvPNU4qwzbpJQAbUSqud2Wt/YjPOmXH7fHkW1RE=";
        "1.0.1t" = "sha256-Sm7kkaL9si5RnHb9wqYouzzsEnYs1FaGHSB5lsigcIg=";
        "1.0.1u" = "sha256-QxK0yhIVtvLJcAdQPYDbgNUVf3b499P+u+a0xW/yZzk=";
        "1.0.2d" = "sha256-Zxw2SHeFYopwM3TGUq0s6+pF+pIK5WgVFd8l2fLJqMg=";
        "1.0.2e" = "sha256-4jzK/bdc/N54LaAVFzGqIYUZWsdF7qOEYTPy4FwOC/8=";
        "1.0.2f" = "sha256-kytO5N7ytDT4VDXZ4+GcqLqZzpoGWmFSS0KanV6bLpw=";
        "1.0.2g" = "sha256-t4Sxs5B845q/QJhwLa3mNlUiolOtFVLiZ6mg6JWUqjM=";
        "1.0.2h" = "sha256-HUAH5TqtlKWyAC/gRe57sLPZjxpH+LK8hR3NHHQzKRk=";
        "1.0.2i" = "sha256-kodIfRHJVFtu+yh823BTXU6bKE3RDVFEHZuZY9AA3m8=";
        "1.0.2j" = "sha256-56/ykr4hwlnGryZGnHqbO6Jumrqv/TJePczJeFJWxDE=";
        "1.0.2k" = "sha256-azl3xh8q7fD5Y2fc+1xuV4zzfnuNkTtOy2ZDw8uI2MA=";
        "1.0.2l" = "sha256-zgcZW2WedfTh20NVKGAHAGHxVqmLs3tnKxAbpuPd8ww=";
        "1.0.2m" = "sha256-jG/xXsazGbUHiPQserwokMCLpaHNzTgQ65CS3q2jew8=";
        "1.0.2n" = "sha256-Nwurt18njDngxQ6MTnSTvA8Y22hnR4NBqDKpgv0VqP4=";
        "1.0.2o" = "sha256-7D9clxS6D9RctOCHMB6xM2wxfg0gtXWhJQUEcOgInk0=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          forceGccName = true;
          cStandard = "gnu17";
        };
        patches = [
          {
            file = ./ordinary/1.0-build-order.patch;
            reason = "Backport recursive build prerequisites from OpenSSL 1.0.1p and 1.0.2d.";
          }
        ];
      };
      releases = {
        "1.0.1" = "sha256-TZ8KWUqaibKOGgSpUEwEEE9lCO4nrR4O/dF6em277u4=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      releases = {
        "1.0.2p" = "sha256-UKmOB7Gonrj2qZR38mLfccb6e+93303IMCWihFyCfQA=";
        "1.0.2q" = "sha256-V0TPy87CsbSGKfc1QgO8Hl6bVGaZi7zMW1/N47GOtoQ=";
        "1.0.2r" = "sha256-rlHQi7qKg5WOiUlG8VMD/4lNdcK4u9RKhStk4/4R0NY=";
        "1.0.2s" = "sha256-yr1clJKCXOW9I/PDru1ql/gUL2BtiT3yFkEfB9Grq5Y=";
        "1.0.2t" = "sha256-FMtGTv56xrVHmbNEVr1pVYp0mkkx7P2c+fcdeIHKx7w=";
        "1.0.2u" = "sha256-7NDG/7ST3QZwfTixS7TYwiiLtwM3NWBladj5D4lmnRY=";
      };
    }
    {
      def = {
        builder = ./build-1.1.0.nix;
        deps = {
          buildPerl = tvp.lib.packages.withConstraint {
            reason = "OpenSSL 1.1.0–1.1.0g Configure imports File::Glob qw/glob/; Perl 5.30 removed that export. Eight consumer holds remain unwaived.";
          } tvp.packages.perl_5_28;
          perl = tvp.lib.packages.withConstraint {
            reason = "OpenSSL 1.1.0–1.1.0g Configure imports File::Glob qw/glob/; Perl 5.30 removed that export. Eight consumer holds remain unwaived.";
          } tvp.packages.perl_5_28;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      releases = {
        "1.1.0" = "sha256-9caf+awUcsgLho78HBwNjc/HRtKevlY94jZd1W29jII=";
        "1.1.0a" = "sha256-wuaW40KWzeLJ7F3NrZ5PBCzXA5MlkdOVw4neSIMCRCs=";
        "1.1.0b" = "sha256-pF3gcr+b5N6kNyMKrwNgAPDmjGpmWTHFfna1sDbO9vc=";
        "1.1.0c" = "sha256-/ENkQaLgV1LTG05GEV64lwmiiu+W1P54ar6SQJsv1vU=";
        "1.1.0d" = "sha256-fV67nol1ZUXBVv+cE88qpiFBk7AQpGijvHicPCj+YN8=";
        "1.1.0e" = "sha256-V76GGJedgMkQcoz8mTab+XsqGr2PNmq2697ol1rTh0w=";
        "1.1.0f" = "sha256-EvdG8/JJOy852n7PY9fuGcasnsak/NjCKdqKUiyxJ2U=";
        "1.1.0g" = "sha256-3k1QEmfaOTEJBcttyMYSH3osrUWncH9234KP4bhQc68=";
      };
    }
    {
      def = {
        builder = ./build-1.1.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      releases = {
        "1.1.0h" = "sha256-WDVibN6emWVlhfx6qiMCpzp+E0C/jBT9Y1pixmgCpRc=";
        "1.1.0i" = "sha256-67/IRKjIzA6l3BC4bJzpf0AYN/P6CMF7LNrcEYJTz5k=";
        "1.1.0j" = "sha256-Mb7GwgPOGo6T1ZlPTtMExjzPB2dhGLZjTt3tEq0bMkY=";
        "1.1.0k" = "sha256-76SWX093NXTWy9oc+HTbvkVascDU+QYRX4Z9MEREcLE=";
        "1.1.0l" = "sha256-dKL3VsZP1zhqKRhNwDRPSDEZLWHcJIGpOkxd1yf0EUg=";
      };
    }
    {
      def = {
        builder = ./build-1.1.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          installedInterface = {
            sha256 = true;
            pbkdf2 = true;
            providers = false;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = true;
            modernCli = false;
            cmake = false;
          };
        };
      };
      releases = {
        "1.1.1" = "sha256-KDaHWg+JwD0P30g5QVEmE6UM+0Idb9lLn0HXJ51Yaj0=";
        "1.1.1a" = "sha256-/CATD4t8vS+5GLLxTi9CnhCcMd3Q+zj8XXHZ/+0/n0E=";
        "1.1.1b" = "sha256-XFV7AjIwQT37B1bzE3oT5tcmg4zNFDCIitFb+ytD6ks=";
        "1.1.1c" = "sha256-9vswea0VB2FU7alBP+1Ch31mjnBp2bhzltCAT9s/TJA=";
        "1.1.1d" = "sha256-HjqRvB+d/OAa8mAm+FbgZOq0yO4Kj0V7WuMLQLi3EfI=";
        "1.1.1e" = "sha256-aU9hrBHLUcm/c/VOdx/2AisDJ6Q7vfobLxneFmKm3L4=";
        "1.1.1f" = "sha256-GGxr/m7PunpbSMR/ihZz0POw5bouJWAt0jtimXXaPzU=";
        "1.1.1g" = "sha256-3bBHdPHjLwxJdR4htnIWrIeFLOsFa3UgmvJENABjbUY=";
        "1.1.1h" = "sha256-XJyod0vXsD5XhPJq6enm10nJ2iQ4VFB35rPXVaBlldk=";
        "1.1.1i" = "sha256-6L5qNf5B0QYDw8xjXpMontAL80t5Zxo6TeZPzuANUkI=";
        "1.1.1j" = "sha256-qvL8tXXN9kkbmKtIKav3ij3shAK4uB78jyPADUQ5gb8=";
        "1.1.1k" = "sha256-iSoIdbmHKs0Eqf3nmx+UMHXV6hYkFd4wR8Mn3zP7ruU=";
        "1.1.1l" = "sha256-C3o+XlnDSCf+DDp0t+yLrvMCuY+oAIjX+RU6oW+na9E=";
        "1.1.1m" = "sha256-+JGZvosjykX8fLnx2NPuZzEjGChq0DD1MWrKZGLbbJY=";
        "1.1.1n" = "sha256-QNzrUaT2pSdb3g5r8g70uRv8Mu1XwFUuLo4VRjNysXo=";
        "1.1.1o" = "sha256-k4SisFcN2ANYhBRkZ3EV33he25QccSEfdQdtcv5rQ48=";
        "1.1.1p" = "sha256-v2G2Kqpmx8djmUKpTeTJroKAwI8X1OrC5EZE2fyKzm8=";
        "1.1.1s" = "sha256-xawB52Dub/Dath1rK70wFGck0GPrMiGAxvGKb3Tktqo=";
        "1.1.1t" = "sha256-je6bJL2x3L8MPR6bAvuPa/IhZegH9Fret8lndTaFnTs=";
        "1.1.1u" = "sha256-4vjYS1I+7NBse+diaDA3AwD7zBU4a/UULXJ1j2lj68Y=";
        "1.1.1v" = "sha256-1ml+KHHncjhGBALpNi1H0YOCsV758karpse9eA04prA=";
        "1.1.1w" = "sha256-zzCYlQy02FOtlcCEHx+cbT3BAtzPys1SHZOSUgi3asg=";
      };
    }
    {
      def = {
        builder = ./build-1.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          forceGccName = true;
          testCompileFlags = [ "-Wno-error=incompatible-pointer-types" ];
          cStandard = "gnu17";
        };
        patches = [
          {
            file = ./ordinary/1.0-build-order.patch;
            reason = "Backport recursive build prerequisites from OpenSSL 1.0.1p and 1.0.2d.";
          }
        ];
      };
      releases = {
        "1.0.0f" = "sha256-+vHqsO+F/Ww77KJxw1azG1zIMeLGt/I89nLnq0aA/eE=";
      };
    }
    {
      def = {
        builder = ./build-1.1.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          testCompileFlags = [ "-Wno-error=implicit-function-declaration" ];
          installedInterface = {
            sha256 = true;
            pbkdf2 = true;
            providers = false;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = true;
            modernCli = false;
            cmake = false;
          };
        };
      };
      releases = {
        "1.1.1q" = "sha256-15Oc5hQCnN/wtsIPDi5XAxWKSJpyslB7i9Ub+Mj9EMo=";
      };
    }
    {
      def = {
        builder = ./build-3.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      releases = {
        "3.0.0" = "sha256-We7fy0bCUhTJvTftYHgpe03wHQEiZ/6enu4x9hvHBTY=";
        "3.0.1" = "sha256-wxGthTNTvOeW7a0BqGLFCopYf2Ln4hAO9GWrU+ybBtE=";
        "3.0.2" = "sha256-mOkczq1NR1auPJzeXgkZGo5YbZ9NUIOOfsCdZBHf22M=";
        "3.0.3" = "sha256-7gB4rc7x3l8APGLIDMllJ3IWCcbzu0K3eV3zH4tVjAs=";
      };
    }
    {
      def = {
        builder = ./build-3.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      status = {
        level = "degraded";
        reason = "CVE-2022-2274: RSA corrupts memory on x86_64 CPUs with AVX512IFMA. The rsa test aborts, so it is not run here.";
        needs = "Nothing — upstream fixed it in 3.0.5. This release is preserved as it shipped.";
        knownTestFailures = [ "rsa" ];
      };
      releases = {
        "3.0.4" = "sha256-KDGEPppmigq0eOcCCtY9LWXlH3KXdHLcc+/O+6/AwA8=";
      };
    }
    {
      def = {
        builder = ./build-3.6.3.nix;
        deps.buildPerl = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "The earlier source-GNU Perl is the isolated Configure/diagnostic build-host role; runtime Perl remains a separately selectable provider.";
        } (import ../../../bases/source-gnu { }).tools.perl;
        deps.perl = tvp.packages.perl_5;
      };
      releases = {
        "3.6.3" = "sha256-JDqGZJz28j7rai/yRW4J5dd92QGKVNPZawxr3Wumx/E=";
      };
    }
    {
      def = {
        builder = ./build-3.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      releases = {
        "3.0.5" = "sha256-qn2Nm+9xrWUlxVuhHl9Dl4ic5Jwsk0nc6m0+TwsCSno=";
        "3.0.7" = "sha256-gwSdBComDmlvYkBqxcCL9wb9hDg/lFzyG9YentlcOW4=";
        "3.0.8" = "sha256-bBPSvzj98x6sPOKjRwc2c/XWMmM5jx9p0N9KQSU+Sz4=";
        "3.0.9" = "sha256-6xqwR4FHQ2D3fDGKuJ2MWgOrw45j1lpgPKu/GwCh3JA=";
        "3.0.10" = "sha256-F2HU9bE6ECi5tvPUuOF/6wztyTcPav5h1xk9LNzoMyM=";
        "3.0.11" = "sha256-s0JdO7SiIY0Gl+tB9/wM3t4BbtGcpJ0Wi3jo2UeIf1U=";
        "3.0.12" = "sha256-+Tyejt3l6RZhGd4xdV/Ie0qjSGNmL2fd/LoU0La2m2E=";
        "3.0.13" = "sha256-iFJXU/edO+wn0vp8ZqoLkrOqlJja/ZPXz6SzeAza4xM=";
        "3.0.14" = "sha256-7soDXU3U6E/CWEbZUtpil0hK+gZQpvhMaC453zpBI8o=";
        "3.0.15" = "sha256-I8Zm0O3yDxQkmz2PA2isrumrWFsJ4d6CEHxm4fPslTM=";
        "3.0.16" = "sha256-V+A8UP6rXTGxUq8rdk8QN5rs2O6S8WyYWYPOSpn374Y=";
        "3.0.17" = "sha256-39135OobV/86bb3msL3D8x21rJnn/dTq+eH7tuwtuM4=";
        "3.0.18" = "sha256-2Aw09c+QLczx8bXfXruG0DkuNwSeXXPfGzq65y5P/os=";
        "3.0.19" = "sha256-+lpBQ7iq4YvlPvLzyvKaLgdHQwuLx00y2IM1uUq2MHI=";
        "3.0.20" = "sha256-yAoB38cOzk3CEWiTLDdzkELUBNRszIGlmG3XUxTs2m8=";
        "3.0.21" = "sha256-YX4pr45CH0ZklISkk35IxoXkf0ZIgWfJgviLxOwdUi8=";
        "3.1.0" = "sha256-qqklrZgodFxMrZ2e/rJz3sqCDyzc8sOsfXwSErfEl7Q=";
        "3.1.1" = "sha256-s6phM0IzuFK2PdsEjfGBF3wsZZ651DdgCBGPnAjQdnQ=";
        "3.1.2" = "sha256-oM5puLl+pqNblodSNapFO5Zro8uory3iNlfYtnZ9ZTk=";
        "3.1.3" = "sha256-8DFqLr2J5/I1KXZEVFhon4AwIJN4jEZmkvsqGIsurPY=";
        "3.1.4" = "sha256-hAr1Nmq5tSK95SWCa+PvD7Cvgcap69hMqmAP6hcx7uM=";
        "3.1.5" = "sha256-auAVRn2r8EabE5rakzGTJ74kuYJR/67O2gIhhI3AkmI=";
        "3.1.6" = "sha256-XSvkA2tHjvPLCoVMqbNTByw6DibYpW+PCrn7btMtONc=";
        "3.1.7" = "sha256-BTox+oDPSuvhBoyYfS7x5EzkGIgUJ8RGR1GugAwx0Gw=";
        "3.1.8" = "sha256-0xnaauzeOqb0JrRLv5l0BtlSdcXFmrb271PKqgefRW8=";
        "3.2.0" = "sha256-FMgm8Hx+QzcG+1xp+p4l2rlWhIRLTJYqLPG/GD60aQ4=";
        "3.2.1" = "sha256-g8cyn+UshQZ3115dCwyiRTCbl+jsvP3B39xKufrDWzk=";
        "3.2.2" = "sha256-GXFJwY2enyksQ/BACsq6EuX1LKz+BQ89GZJ36nOOwuc=";
        "3.2.3" = "sha256-UrXxxrgCK8WGjDCMVPt3cF5wLWxvRZT5mg3yFqz0Yjk=";
        "3.2.4" = "sha256-sjrX/Z9z5DrRdn5jYEDoi6fJ5Xdb+lYYQ2oN0sF8NxY=";
        "3.2.5" = "sha256-s2NH0CSg9b0J/vzWr3pYuzCUYIDrjOj3vnhWIZDQmHk=";
        "3.2.6" = "sha256-iWgandqp7XzyXqjvYTONuAUgC65H0AUQSQYjVHOAwUg=";
      };
    }
    {
      def = {
        builder = ./build-3.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
        opts = {
          installedInterface = {
            sha256 = true;
            pbkdf2 = true;
            providers = true;
            engines = true;
            engineModules = true;
            splitPkgConfig = true;
            rehash = true;
            tlsMethod = true;
            modernCli = true;
            cmake = true;
          };
        };
      };
      releases = {
        "3.3.0" = "sha256-U+ZrBDMipgar8Ah+dpmg4DOjf6E/65dC3zXDozsY+wI=";
        "3.3.1" = "sha256-d3zVlihMiDN1oqehG/XSeG/FQTJV76sgxQ1v/m0CC34=";
        "3.3.2" = "sha256-LopAsBl5r+i+C7+z3l3BxnCf7bRtbInBDaEUq1/D0oE=";
        "3.3.3" = "sha256-cSWQ/SCqpg7HXXeP5bgQ1rgpyn+x5TBXeRehMfkQVTk=";
        "3.3.4" = "sha256-jRpfwyPT/TUdwFRYRX/Uj3hlLSpJjh1w/+oHtNDrP6g=";
        "3.3.5" = "sha256-nWLAClppA3QMhwPw4AYlf0KdVl07kawam9SkxwAALgE=";
        "3.3.6" = "sha256-ItsE88j5qAjJeV3PfScT/0DBLEEOotH2Q1xsnIVYlYs=";
        "3.3.7" = "sha256-SQC+VOgcTf4AuxoQ2tM/2EFIM1c8QNDp4ydNTtMuU6I=";
        "3.4.0" = "sha256-4V3agv4v6BOdwqwho21MoB1TE8dfmfRsTooncJtylL8=";
        "3.4.1" = "sha256-ACotazC1i/S+pGxDvdljZar42qbEKHgqpP7uBtoZffM=";
        "3.4.2" = "sha256-F7AkWfwovkFUcMzKrnQ080lsrBMGuGtSyDiGWA6Cg0w=";
        "3.4.3" = "sha256-+nJ+0TmaZOdUAwoDNDUAOZGu42vamlsICZXLKsXPfzc=";
        "3.4.4" = "sha256-e99VrCDyd56Z5eyjBvgk+tKzfe5aBsw17VqLhaYGABA=";
        "3.4.5" = "sha256-xaaSkjTblB7KcJt523HT+8mBnukTJM3qv4mENsINzdw=";
        "3.4.6" = "sha256-pXuKHwm1AskENSyKU4aYdnXy1sUrwVX5ovQW+uocBHM=";
        "3.5.0" = "sha256-NE0KefGpsIApsHROLMQBpD+ckKzRBE0JpTC0iFqOn8A=";
        "3.5.1" = "sha256-UpBDsVz/pfNgd6TQr4Pz3jmYBxgdYHRB1zQZbYibZB8=";
        "3.5.2" = "sha256-xTpH5eRByTDDkoz3v2+wDl0Sm2MOCqhzsIJYZW5zRew=";
        "3.5.3" = "sha256-yUidKrz5Q83IMppXCSMxxZikApOAVNw6IiGK6oqOw78=";
        "3.5.4" = "sha256-lnMR+ElVMWlpvbHY1LmDcY70IzhjnGIexMNP3e81Xpk=";
        "3.5.5" = "sha256-soyRUyqLZaH5g7TCi3SIF05KAQCOKc6Oab14nyi8Kok=";
        "3.5.6" = "sha256-3q58gMupnEtPlA7K2zwzOLE8t3QYQJI45X1/MfKjtzY=";
        "3.5.7" = "sha256-qMDSilKcpID582z1eS4s0hmEVSo8jkqhGiSqMa6smOg=";
        "3.6.0" = "sha256-tqX0S362nj+jXb8VUkQFtEg3pIHUPYHa3d4/8h/LuOk=";
        "3.6.1" = "sha256-sb/tzVson/Iq7ofJ1gD1FXZ+v0X3cWjLbWTyMfUYqC4=";
        "3.6.2" = "sha256-qvUaH+BkOE+BHa6utOxNznNA7IvYkwJ+7mdq8x6DoE8=";
      };
    }
    {
      def = {
        builder = ./build-4.0.1.nix;
        deps.buildPerl = tvp.lib.packages.withConstraint {
          category = "construction";
          reason = "The earlier source-GNU Perl is the isolated Configure/diagnostic build-host role; runtime Perl remains a separately selectable provider.";
        } (import ../../../bases/source-gnu { }).tools.perl;
      };
      releases = {
        "4.0.1" = "sha256-LbPzoNbqS1nh8JSs4sjNU23/uHzcOQhMWvoeb3833Qk=";
      };
    }
    {
      def = {
        builder = ./build-4.0.0.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      releases = {
        "4.0.0" = "sha256-wyz0mpWcTzRflgaYLdNufSj3xYsZwuJddWJNKz0veaw=";
      };
    }
    {
      def = {
        builder = ./build-0.9.6.nix;
        deps = {
          buildPerl = tvp.packages.perl_5;
          perl = tvp.packages.perl_5;
          runtimeCoreutils = tvp.packages.coreutils;
          runtimeSed = tvp.packages.gnused;
          runtimeGrep = tvp.packages.gnugrep;
          runtimeGawk = tvp.packages.gawk;
          runtimeFindutils = tvp.packages.findutils;
        };
      };
      status = {
        level = "broken";
        reason = "Configure has no x86_64 target: 0.9.6 predates AMD64 and offers only alpha, ia64, m68k, mips, ppc, s390, sparc and 32-bit linux-elf.";
        needs = "A period-appropriate architecture. Not fixable on x86_64-linux.";
        blocked = {
          platform = "pre-amd64";
        };
      };
      releases = {
        "0.9.6" = "sha256-UhW2cMJnTfmmQlZepopn5tlV2O/MoaobTmpbT9J0Tug=";
        "0.9.6i" = "sha256-59i6mRAKUQetrEZd6MsVzTX9ScxtwbEnMWmAhUVlg1k=";
        "0.9.6j" = "sha256-PPct3ugGSOpFZ7Aw0C1bMdLhCVuDCD/tRO3boYWpkwM=";
        "0.9.6k" = "sha256-eLPwYwnagXHFwGuq/TAh3I/TMNYoxTXQhdWqcagROtE=";
        "0.9.6l" = "sha256-JyPnyLT66JkY89QKbRq53WGATe2Zh/aOAJr+i3B43Zc=";
        "0.9.6m" = "sha256-p3jAe13iSOGrizc0O8xgM/s62VXN1XmV6awKRM6UL9Y=";
      };
    }
  ];
  pname = "openssl";
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;

    source = tvp.lib.sources.archive {
      url =
        version:
        if pkgs.lib.versionOlder version "3.0.0" then
          "https://github.com/openssl/openssl/releases/download/OpenSSL_${
            builtins.replaceStrings [ "." ] [ "_" ] version
          }/openssl-${version}.tar.gz"
        else
          "https://github.com/openssl/openssl/releases/download/openssl-${version}/openssl-${version}.tar.gz";
      discovery = {
        type = "git-tags";
        url = "https://github.com/openssl/openssl";

        # Releases that exist upstream and cannot be packaged at all. Listed so
        # the delta separates work from dead ends, rather than showing both as
        # "not packaged" forever.
        unavailable = [
          {
            versions = [
              "0.9.1c"
              "0.9.2b"
              "0.9.3"
              "0.9.3a"
              "0.9.4"
              "0.9.5"
              "0.9.5a"
              "0.9.6a"
              "0.9.6b"
              "0.9.6c"
              "0.9.6d"
              "0.9.6e"
              "0.9.6f"
              "0.9.6g"
              "0.9.6h"
            ];
            reason = "No tarball is served by openssl.org or by GitHub releases. Only git-archive snapshots survive, and a snapshot is a different artifact from the release.";
          }
        ];

        # Two tag conventions, split at 3.0: OpenSSL_1_1_1w and openssl-3.0.0.
        # Anything else (rsaref, the fips branches) is not a release.
        normalise =
          tag:
          if pkgs.lib.hasPrefix "OpenSSL_" tag then
            pkgs.lib.replaceStrings [ "_" ] [ "." ] (pkgs.lib.removePrefix "OpenSSL_" tag)
          else if pkgs.lib.hasPrefix "openssl-" tag then
            pkgs.lib.removePrefix "openssl-" tag
          else
            null;

        # A release version starts with a digit. That rule, rather than another
        # blacklist entry, is what drops OpenSSL_FIPS_1_0 — the separately
        # distributed FIPS Object Module, which has no openssl-*.tar.gz at all.
        # "-post-reformat" and friends tag repository maintenance, not releases.
        include =
          version:
          let
            # Published, then pulled: no tarball is served for either, and 3.0.6's
            # tag no longer exists. A rule cannot express this, so the predicate
            # closes over the list rather than a separate `exclude` field.
            withdrawn = [
              "1.1.1r" # withdrawn 2022-10-11, superseded same day by 1.1.1s
              "3.0.6" # withdrawn 2022-10-11, superseded same day by 3.0.7
            ];
          in
          builtins.match "[0-9].*" version != null
          && !(pkgs.lib.elem version withdrawn)
          && !(
            pkgs.lib.hasInfix "pre" version
            || pkgs.lib.hasInfix "alpha" version
            || pkgs.lib.hasInfix "beta" version
            || pkgs.lib.hasInfix "rc" version
            || pkgs.lib.hasInfix "-post-" version
          );
      };
    };
    tests = import ./tests;
    testDeps = {
      pkg-config = tvp.packages.pkg-config;
      cmake = tvp.packages.cmake;
    };
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.openssl = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases {
    inherit pname canonical;
    inherit versionTable;
  };
}
