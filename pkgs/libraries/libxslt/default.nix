{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  pname = "libxslt";
  upstream = "https://download.gnome.org/sources/libxslt/";
  extensionsStdlibPatch = {
    file = ./ordinary/extensions-include-stdlib.patch;
    reason = "Backport 1.1.39's explicit stdlib.h include so getenv has its declaration on Unix.";
  };
  dateStdlibPatch = {
    file = ./ordinary/exslt-date-include-stdlib.patch;
    reason = "Backport the 1.1.39 stdlib.h include for getenv and strtol in the EXSLT date module.";
  };
  versionTable = tvp.lib.packages.mkTable [
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps = {
          libxml2 = tvp.lib.packages.withConstraint {
            reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
          } tvp.packages.libxml2_2_7_8;
          gnu-config = tvp.packages.gnu-config;
        };
        opts = {
          compression = "gzip";
          legacyXslAttributes = true;
          license = lib.licenses.gpl2Only;
        };
        patches = [
          {
            file = ./ordinary/0.1.0-htmltree-declaration.patch;
            reason = "Include libxml2’s HTML tree header for the serializer declaration, as upstream does from 0.7.0.";
          }
        ];
      };
      releases = {
        "0.1.0" = "sha256-sgccum9NWyx84QEvj5CvWbU1z2Tqg2MRuR3/BIjOJRg=";
        "0.2.0" = "sha256-W02B0mUHIcHXzrbwI2dhoIS8+wU4s7hf4Jr0DNfd/o4=";
        "0.3.0" = "sha256-rpMYSBL3VEjg4IJCEVfZxH1UU+qvD0zsc0tSRvY+fBk=";
        "0.4.0" = "sha256-bAPxFJkDMY2r3SrhDXukLN+ovCZEpvnEekIpPy65GVE=";
        "0.5.0" = "sha256-n/huHVbsbBRW0G80s7dhplf9VPAXSn+wqRx8jjeviLo=";
        "0.6.0" = "sha256-nwg88c7ydmJaaQTlqn9B40hzRUrdOJARlTjCE31nHCg=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps = {
          libxml2 = tvp.lib.packages.withConstraint {
            reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
          } tvp.packages.libxml2_2_7_8;
          gnu-config = tvp.packages.gnu-config;
        };
        opts = {
          compression = "gzip";
          legacyXslAttributes = true;
          license = lib.licenses.gpl2Only;
        };
        patches = [
          {
            file = ./ordinary/0.7.0-ansidecl.patch;
            reason = "Guard ansidecl.h with its configure check, as upstream does in 0.8.0.";
          }
        ];
      };
      releases = {
        "0.7.0" = "sha256-eZM7Gf+1UBsRJYvKelKHrpPUcvHCBjpIHS3o982SuSU=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps = {
          libxml2 = tvp.lib.packages.withConstraint {
            reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
          } tvp.packages.libxml2_2_7_8;
          gnu-config = tvp.packages.gnu-config;
        };
        opts = {
          compression = "gzip";
          legacyXslAttributes = true;
          license = lib.licenses.gpl2Only;
        };
      };
      releases = {
        "0.8.0" = "sha256-42BjrYG3+z9dORUg+3cE6b2JSAR7EIE2Oj+hqy6MCAU=";
        "0.9.0" = "sha256-36W3Q99n2eglfFZmAMbuezia0DSRGweWbqnl46LeipM=";
        "0.10.0" = "sha256-exvaZoOTsI2VAqLWp2rzOPNERBKynRI2pl5KTlhuzy8=";
        "0.11.0" = "sha256-bu6QdBv/Fy3vC4lP3fGmSvW4UwpauZdjDkbW0GL6PEs=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps = {
          libxml2 = tvp.lib.packages.withConstraint {
            reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
          } tvp.packages.libxml2_2_7_8;
          gnu-config = tvp.packages.gnu-config;
        };
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
        };
      };
      releases = {
        "0.12.0" = "sha256-3ZAC5IYf3ENr8u9Pn7m0uIcfFtmqU68hPsNrVilfaD4=";
        "0.13.0" = "sha256-aT0ViJS69ovOcfzEp7iREGTuHgLY87xJ0WdRie086tA=";
        "0.14.0" = "sha256-wuaghrhUBodYaKPKcAn1IbHsMgazn6U8tXUxDvesIZc=";
        "1.0.0" = "sha256-aSX7OQDqGS6b5ILg3gWHBFc3yupz3GMkIbsp5DNL+hM=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps = {
          libxml2 = tvp.lib.packages.withConstraint {
            reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
          } tvp.packages.libxml2_2_7_8;
          gnu-config = tvp.packages.gnu-config;
        };
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
          withExslt = true;
        };
        patches = [
          {
            file = ./ordinary/1.0.1-document-pointer.patch;
            reason = "Return the document pointer from the cache lookup, as corrected upstream.";
          }
          {
            file = ./ordinary/1.0.1-exslt-function-headers.patch;
            reason = "Backport the 1.0.2 headers for memset and xsltApplyOneTemplate.";
          }
        ];
      };
      releases = {
        "1.0.1" = "sha256-Nsu00hzfuQG7QQci3zQs3WCZP07GLqQABZmWAoGp+xE=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
          withExslt = true;
        };
        patches = [
          {
            file = ./ordinary/1.0.2-extension-error-context.patch;
            reason = "Pass the transform context to the diagnostic helper as upstream does in 1.0.3.";
          }
        ];
      };
      releases = {
        "1.0.2" = "sha256-1fMwoR9/6Ua7sxjG2nBPZzeg6dDNPDFrML10Dk1a/dc=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
          withExslt = true;
        };
      };
      releases = {
        "1.0.3" = "sha256-uW6VwHXtNCWX4osKjDOiAdRwazMV8vmQ/z3TY6bzQJE=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
          withExslt = true;
        };
        patches = [
          {
            file = ./ordinary/1.0.4-date-string-header.patch;
            reason = "Backport the explicit string.h include for memset.";
          }
        ];
      };
      releases = {
        "1.0.4" = "sha256-8z+63K/WiuMxD07OiQ3BJJdKR4acxx6OJL6qd+cDzkU=";
        "1.0.5" = "sha256-n4pdS1X2JuOxXx0nZYkRwE/JjfFlVTjNXiEIgyB3VTI=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
          withExslt = true;
        };
      };
      releases = {
        "1.0.6" = "sha256-dxyFD63CHmu9EkmhasFrghQqt8GbjbeGlaUTMMWp2Y8=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "gzip";
          license = lib.licenses.gpl2Only;
          withExslt = true;
          withBreakpoint = true;
        };
      };
      releases = {
        "1.0.7" = "sha256-tLgVLmuNbIB+sSrJzqnfLLrjoFvT5uWXXQMVU7I6oN0=";
        "1.0.8" = "sha256-6bKqWsASvrPxRJ+jv286svL+MAv6ezRJGq2YVs9Ro2o=";
        "1.0.9" = "sha256-jg6GbOmCEKIxp8wfZizVhx+xMfpLrlo1FPeuSFqBpto=";
      };
    }
    {
      def = {
        builder = ./build-0.1.0.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          license = lib.licenses.gpl2Only;
          withExslt = true;
          withBreakpoint = true;
          pkgconfig = true;
          repairPkgconfigRequires = true;
        };
        patches = [
          {
            file = ./ordinary/1.0.10-dtd-node-pointer.patch;
            reason = "Backport the upstream conversion to a node pointer before traversing the DTD.";
          }
        ];
      };
      releases = {
        "1.0.10" = "sha256-c8qUANVMqUTDDUl2gjhFkV0Xdq+SsNuftkkW25nN/ag=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
          repairPkgconfigRequires = true;
        };
      };
      releases = {
        "1.0.11" = "sha256-n4EEHpijdckd2UYKR6icmh3E3hgEZjE8m4fmlfEeeog=";
        "1.0.12" = "sha256-JMz19YiZUT1UAQbDvEGlLQGTpF+G0zV6BQ24StByXhQ=";
        "1.0.13" = "sha256-yIwWwq8JLqfgsAVgBSg6xqJtW1oEmbNbyVgS+h6irPM=";
        "1.0.14" = "sha256-x9swB7u70QR2R47OFAXsEhoo4Ula71SScbYyuNOWoSY=";
        "1.0.15" = "sha256-OWfzceE5wKYQTfqp1OA9kBffVKFvO6MmMgtQn39GDSE=";
        "1.0.16" = "sha256-BZ60evB9lqRZ9P5T1zqa82hclh9vLw7Qj4PagJQLv5Q=";
        "1.0.17" = "sha256-+BPHTFvSmylpCbPrIWWCucpyoDBfAU///YGbwPvHEaM=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
      };
      releases = {
        "1.0.18" = "sha256-kBHxZiv1GR0XulZUipT4v9X0Ci+7dENJfi2EB2gpwik=";
        "1.0.19" = "sha256-0KOetW+Y6wBNM507/xXHw6WBIFJ7iDBwtO/F9MCVKXM=";
        "1.0.20" = "sha256-eHloBcstoHbGbL00aAQIUamGy+T67RZGg/v0ylfIeLU=";
        "1.0.21" = "sha256-/rxirZF/DirqNy5zXWNsR/kV5NG1OSernTAi6rfvECE=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        patches = [
          {
            file = ./ordinary/1.0.22-attribute-namespace-lookup.patch;
            reason = "Use the namespace URI for xmlHasNsProp, as corrected upstream in 1.0.23.";
          }
        ];
      };
      releases = {
        "1.0.22" = "sha256-i5OTAPnbjV0e0a/ia24bQsw2k1lWmOIy4hM3f3z1K8I=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
      };
      releases = {
        "1.0.23" = "sha256-YbroBluA+JkVUrU9zpLhtK5gohvimBg1NjPWB3pluXY=";
        "1.0.24" = "sha256-uhmGa4rTAHBPfwtqqomJRqTHa9R6DtyYUCxDDGvzGVM=";
        "1.0.25" = "sha256-O/x8BixZ25SN5z2RRHLjBS/x19ANN03ds5A+oVxfeMw=";
        "1.0.26" = "sha256-Eqc+jt72gt+PLxTjuWc1Sb5lQJQWKxw9NHT6whZ9UFE=";
        "1.0.27" = "sha256-6oCTgDDO32XWo5hfjV+ld08bBwk06cTeOBJuFWS9rCM=";
        "1.0.32" = "sha256-PFpJ8tZSGYF2VxnQR88AXSmn8OMQBciQ46qyekDt+wo=";
        "1.0.33" = "sha256-MjUwRCHaQWKBh81i8Fx02KXeJjEUOSBcZRllUq7J/ls=";
        "1.1.0" = "sha256-rQOPBpKl5S/Tw8R7d67AkReHiITi7tRbeR/s8Wo9758=";
        "1.1.1" = "sha256-VgHTanXSxOqDEeO4yiyJ5UjcPLPJ8AKwy9aMfbYthfQ=";
        "1.1.2" = "sha256-X5BEPqgxa5L9/rZZUQ+AaTOLCtG0eHWc1vmL8vvFduU=";
        "1.1.4" = "sha256-b+1HJBBsfslDHB6P/yv8+mQGWYFc3taZsNbtmVRqTrE=";
        "1.1.5" = "sha256-E8DqJZEjPrnDFG+xD2k11QtF7A2lpEfMd364Y5pKxgo=";
        "1.1.6" = "sha256-iEpATeuPA75p6DBQ6B+BIaibkhaLWoaxGlK7psQRBrw=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.8" = "sha256-wSWbTSK55iO1Ep0ckiWAAirvMAL6+z6NX0+GMgwN4d0=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        patches = [
          {
            file = ./ordinary/1.0.28-value-tree.patch;
            reason = "Backport 1.0.30's conversion of document pointers passed to xmlXPathNewValueTree.";
          }
        ];
      };
      releases = {
        "1.0.28" = "sha256-qjDzIxqDX8dGA3lfN/Bs5BA8cxJ9a66Izlqq5tpTDG8=";
        "1.0.29" = "sha256-e1WuxCjWJXRSvgJURs0EYHHitL+lgVbSiesZTjaD1Kg=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        patches = [
          {
            file = ./ordinary/1.0.30-parameter-lookup.patch;
            reason = "Backport 1.0.31's pointer-typed hash-table lookup for global parameters.";
          }
        ];
      };
      releases = {
        "1.0.30" = "sha256-cR9XuP82naP+IH23Y0NIV77GZXOV6S0FR823A/MDRHI=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        patches = [
          {
            file = ./ordinary/1.0.31-copy-namespace.patch;
            reason = "Backport 1.0.32's conversion of the namespace node before xsltCopyNamespace.";
          }
        ];
      };
      releases = {
        "1.0.31" = "sha256-jojZo+yv5G7R6ub6HqIdRU/OdDh57q6QeNaxHI7GTZg=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        patches = [
          {
            file = ./ordinary/1.1.3-qname-and-string-declaration.patch;
            reason = "Backport 1.1.4's QName argument conversion and explicit string.h include.";
          }
        ];
      };
      releases = {
        "1.1.3" = "sha256-4OLzYFrRxiqUDFrolwft6DizBcaalMTJNQMj/MTCp3s=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These early libxslt sources use the legacy xml2-config and libxml2 API from the 2.7 line.";
        } tvp.packages.libxml2_2_7_8;
        opts = {
          compression = "bzip2";
          configureOptions = [ "--without-python" ];
        };
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.9" = "sha256-rVwHWkkDdlmnRr9kL1kHXLj7r67xc970pTO/6lk4D7A=";
        "1.1.10" = "sha256-QWLOVdMDSeZ+rKK6dAbWrMmBPWvo2N28fjCvaL1SreE=";
        "1.1.11" = "sha256-E2f+n2DjhGCxDgmM772MTOMwCrD8VI1JyJzFu7rmkMY=";
        "1.1.12" = "sha256-SIZ4BJCHLGHeXv6pKaDYnPQQGl5PrG51oOXrRq2lm4I=";
        "1.1.13" = "sha256-Wg1bpYeM4Nitw4vDiTe7XloFy9s+4tdw+Pc+CbwzT9A=";
        "1.1.14" = "sha256-sEKPOqJTezoIANMD/e4rHYBsfv2d3nBjGk6p4lNnCb8=";
        "1.1.15" = "sha256-YyIST0cdbtSQiDPN2rpRKyR6oWnLjR69hyGa/gUcbgM=";
        "1.1.16" = "sha256-nphAsrvkvcfAr+uj7pgf3rSWTSxBCc7RJ8zJ75danDc=";
        "1.1.17" = "sha256-8t3xz3s4TyExGL/2QD9EZfB+BVpSp7va374fZ8Z23mA=";
        "1.1.18" = "sha256-DOB1rh2BLy1BzF8e3bM1HFPJgfg7hcjIT0Q3dcVf8EA=";
        "1.1.19" = "sha256-uSqQ5UzoDc74YkRC95YvAca3ObtqZDq0xqmvRSdCvh0=";
        "1.1.20" = "sha256-QczgeUOniNqGFtAUB8GtudFIJ3D1kSxxGWTd0xtCjL8=";
        "1.1.22" = "sha256-oL811I0adESCMJsNUZDxWWdoS5NRlf4/BvKYeL6DjJE=";
      };
    }
    {
      def = {
        builder = ./build-1.0.11.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These sources use the public xmlBuffer layout and non-const xmlHashScanner callback from before libxml2 2.9.";
        } tvp.packages.libxml2_2_8_0;
        opts = {
          compression = "xz";
          configureOptions = [ "--without-python" ];
        };
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.23" = "sha256-jLCMbT6ugjx8CGJ4Wrqj21A4EbmslG1XB2mCHXBHr1A=";
        "1.1.24" = "sha256-nmRjLhpZWlff6MpS9XMRg6kyd+Eeds6gnsrERJ5fBkk=";
        "1.1.25" = "sha256-mbYAG0hPcxp/FNu0ldOwp/Cnr0g1bbYrWU2zjxqAWAE=";
        "1.1.26" = "sha256-wlLo04r0zQuXbgR3L+vgo9Oqz0nLwKXWY/B4nIfJznM=";
        "1.1.27" = "sha256-xB9qXP/cDIEplhUaO7OQCuR/WPhvESXJPlA+ehjTG4M=";
        "1.1.28" = "sha256-LnZD1IX+Zk0rB/pgNvPiy+3OOykQUg48yn3pP71c09I=";
        "1.1.29" = "sha256-Fynd9+O2vRaPCehcZO5+hQNbRLzsxD5Eas+YArygp9k=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These libxslt releases precede the libxml2 2.13 API removals.";
        } tvp.packages.libxml2_2_12_10;
        opts.linkLibxml2Compression = true;
        patches = [
          extensionsStdlibPatch
          dateStdlibPatch
          {
            file = ./ordinary/extensions-hash-callback.patch;
            reason = "Backport 1.1.33's const-correct xmlHashScanner signature for libxml2 2.12.";
          }
        ];
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.30" = "sha256-2x5OJursR9APiFutGah0nrEAiQm4F9ZQEBNl8GjuOyQ=";
        "1.1.31" = "sha256-Z4AMZqq/7e1W9EmGKEEJ+1MndqwJYJh+dUU93ic1Obg=";
        "1.1.32" = "sha256-t9qQ6qaw2unpo3aeKadXNC7vDtuae0MUJIFDdUFEIq8=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These libxslt releases precede the libxml2 2.13 API removals.";
        } tvp.packages.libxml2_2_12_10;
        opts.linkLibxml2Compression = true;
        patches = [
          extensionsStdlibPatch
          dateStdlibPatch
        ];
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.33" = "sha256-OUTTp0tMprQPWZZ+Klh6vGmU9pNdaX2fobjt1yJRPpA=";
        "1.1.34" = "sha256-KMR9szq02u+mIy8xzLPGUmDIJRUeyG7EYTVSR/P1aCQ=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These libxslt releases precede the libxml2 2.13 API removals.";
        } tvp.packages.libxml2_2_12_10;
        patches = [
          extensionsStdlibPatch
          dateStdlibPatch
        ];
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.35" = "sha256-gkfzPpqHLGrIWapFAYvExNALl+L+rJ7rwQyTzh803Xk=";
        "1.1.36" = "sha256-EoSPCkQI9ltTDTlizZ/2cLaueWGRz+/zdSK1dy3o3I4=";
        "1.1.37" = "sha256-Oksn3IAnzNYUZyWVAzbx7FIJKPMg8UTrX6eZCuYSOrQ=";
        "1.1.38" = "sha256-HzJFBCWBmgmsr/Krelp/ii7HlW5QXXvutF6EPQ4eyrE=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps.libxml2 = tvp.lib.packages.withConstraint {
          reason = "These libxslt releases precede the libxml2 2.13 API removals.";
        } tvp.packages.libxml2_2_12_10;
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.39" = "sha256-KiCtYhFIM5sHWcTU6WcZNi3uZMmgltu6YlugU4RjSfA=";
        "1.1.40" = "sha256-GUcV2wIwNfZftWZALyrSteq0wp1UH1ETBcQLKbH0jRM=";
        "1.1.41" = "sha256-OtOSr5ERW3dA97UNIozBxfwTr8HafxbLAhORejf3G9o=";
        "1.1.42" = "sha256-hcpiysDUH8d9P2Az2p32/XPSDqL8GLCjYJ/7QRDhuus=";
        "1.1.43" = "sha256-Wj1rODylr8I1sXERjpD1/2qifp/qMwMGUjGm1APwGDo=";
      };
    }
    {
      def = {
        builder = ./build.nix;
        deps.libxml2 = tvp.packages.libxml2_2;
        deps.libgcrypt = tvp.packages.libgcrypt;
      };
      releases = {
        "1.1.45" = "sha256-ms/mhBnE0GpFxVAyGzISdi2S9BRlBiyk6hnmMu5dIW4=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    packageMeta.security = {
      schema = 1;
      purl = "pkg:generic/libxslt";
      cpe = {
        vendor = "xmlsoft";
        product = "libxslt";
      };
    };
    source = tvp.lib.sources.archive {
      url =
        version:
        let
          line = lib.concatStringsSep "." (lib.take 2 (lib.splitString "." version));
          extension =
            if lib.versionOlder version "1.0.10" then
              "gz"
            else if lib.versionOlder version "1.1.23" then
              "bz2"
            else
              "xz";
        in
        "${upstream}${line}/libxslt-${version}.tar.${extension}";
      discovery = {
        type = "json-index";
        url = "${upstream}cache.json";
        selector = ''.[1].libxslt | keys[] | select(test("^[0-9]+[.][0-9]+[.][0-9]+$"))'';
        scope = "GNOME release archives, including historical compression formats.";
        unavailable = [
          {
            versions = [ "0.0.1" ];
            reason = "Requires libxml 1 and its xml-config interface. TVP provides libxml2, whose xml2-config and libxml2 ABI do not satisfy this build.";
          }
          {
            versions = [
              "0.0.0"
              "1.1.7"
              "1.1.21"
              "1.1.44"
            ];
            reason = "Source tags exist, but GNOME's official release archive index does not publish release tarballs for these versions.";
          }
        ];
      };
    };
    tests = import ./tests;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.libxslt = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
