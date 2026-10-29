{ pkgs, tvp }:
let
  tvpLib = tvp.lib;
  base = tvp.bases.default;
  defs = tvpLib.packages.mkDefs {
    "1.0" = {
      builder = ./build-1.0.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_13;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.2" = {
      builder = ./build-1.0.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_13;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.5" = {
      builder = ./build-1.0.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.6" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.gz";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.6.1" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
      opts.headerMacro = "AM_CONFIG_HEADER";
    };
    "1.7" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.automaticCcCo = false;
      opts.archiveExt = "tar.bz2";
    };
    "1.10" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.archiveExt = "tar.bz2";
    };
    "1.11" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.archiveExt = "tar.bz2";
      opts.installAclocalDir = true;
    };
    "1.11.3" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
      opts.installAclocalDir = true;
    };
    "1.12" = {
      builder = ./build-1.6.nix;
      inherit base;
      deps = {
        autoconf = tvp.packages.autoconf_2_73;
        perl = tvp.packages.perl_5_44_0;
      };
    };
  };
  versionTable = tvpLib.packages.mkTable [
    {
      def = defs."1.0";
      releases = {
        "1.0" = "sha256-DAyl3XOif/K6R8GKkbyJTK93g6qaGorzJBJ6oKL/3S4=";
      };
    }
    {
      def = defs."1.2";
      releases = {
        "1.2" = "sha256-5FEV79YJTx+5xhfk2E84af5yy76vrYhZVDC75RsHxbg=";
        "1.3" = "sha256-xqbrs4M11YqlAfp3P6SQQelRNbzOl3sZ78nxRWdAPWA=";
        "1.4" = "sha256-a3Hfp5qM0N4rTN7TJHdDy7lV1DTVfPiJIUQyHreVyWg=";
        "1.4-p1" = "sha256-26J0yUdm2a1jmpoayXaMnA1aQqHLexhieWoZHLEy9+g=";
        "1.4-p2" = "sha256-p42ZQ64D13qYRu97lqP70n4qj1hISyB1pV0vamdHRGU=";
        "1.4-p3" = "sha256-nIQtSkYTURqUQvVK+KpI6lAqRtu1r9WMnlSlhYXVOMk=";
        "1.4-p4" = "sha256-pb2w10605yMN4cRrJ0HQGMkU6PBwK+s4Z0ri3kGuKAs=";
        "1.4-p5" = "sha256-1vJac4eTCyikM04InCnBTzF0ZrTivjtCRHGKUpxBR+o=";
        "1.4-p6" = "sha256-UDzcKwmSpDCVRdF/RiyxX5m7V7cWHfxAgrLnGI8rzA8=";
      };
    }
    {
      def = defs."1.5";
      releases = {
        "1.5" = "sha256-JLR3XjFD/T4121y6uoCEXZNZx7/XUabOvjAU+/YRXXg=";
      };
    }
    {
      def = defs."1.6";
      releases = {
        "1.6" = "sha256-c+BVtxfBPCYH84MR5n8+elGWZvvOsEwJHoVrjhBVEzc=";
      };
    }
    {
      def = defs."1.6.1";
      releases = {
        "1.6.1" = "sha256-dE8RldLUUJgEBGRsjai9LqqOXTeLJCJOyrS5/PtKbrk=";
        "1.6.2" = "sha256-Gt28RbTiylWhonx8kfpLGvNTBd+RwNdzQITysMyYKL0=";
        "1.6.3" = "sha256-Dbr6yvIeE1yrNdNXoUvc2YHS8tAOE4eAG+gJGjG3u4E=";
      };
    }
    {
      def = defs."1.7";
      releases = {
        "1.7" = "sha256-ZjPuEgI3XjyHmKkuG39GiU941UGu6n9JZUUD/cCyiDU=";
        "1.7.1" = "sha256-eDvLQUeoAxfHIBEeHeYXHs1jTIERtCEDbar8kKrAyys=";
        "1.7.2" = "sha256-L+E2dQTnA5riUmp8Ok7M1UP8TBo6KjSrn3vlnoM5wLQ=";
        "1.7.3" = "sha256-ae06ysPjpWJbQzhqvJyKge/tRtvSJMEhKcWx49FDXjY=";
        "1.7.4" = "sha256-p8NN7IEDS6HEARG5S/HiTZKd1ahC+octPHP/CStqxnM=";
        "1.7.5" = "sha256-KLBH5y4CR/fZq2j71GJxF7PR09/CfpObMfzB0drM6k4=";
        "1.7.6" = "sha256-4UTAursjumH/4XPeYQY4IYbsF16GjJeCIQTn94a0YBc=";
        "1.7.7" = "sha256-0smPsSGIRhsFQr2SjpHDdn2yy2zZUaIitsMFvZmnWHg=";
        "1.7.8" = "sha256-Ld3DtRUG5wJkfMxnV+FcBTI/pnJF0tU+ge02qDL5vkI=";
        "1.7.9" = "sha256-MsE7atOO1ee/0XVsvBnPXv1nt63i0GAApMmbDOlL1G0=";
        "1.8" = "sha256-cFZZUFvZ2Y3AbvCE4hM5mrjr5ElZ2Pi9Hxp31A9cepo=";
        "1.8.1" = "sha256-qC+gVn+YFEuujM/O9ROECmi0JXh8eMvqbCFsK3HIaUs=";
        "1.8.2" = "sha256-4X4RSigeo4zXXYkI11+GFqCriok7HQSKHY6wHn5wYFs=";
        "1.8.3" = "sha256-DGVCyrgw3xUOe6Dv9rJW/umwuYqrVtzK0trpnNBQBoQ=";
        "1.8.4" = "sha256-vh1vBHQ87vF5mhRPJggOKZo1LeaNhndmiPCUDg6dZxg=";
        "1.8.5" = "sha256-hMk6qjw2UannR0tyGw5niDGFklCefeYEuv5OqASdxBA=";
        "1.9" = "sha256-mEbvYv47dk/qdpJ8ARzRTh77o3kRd5oISyw+8xHWeIA=";
        "1.9.1" = "sha256-bxasBeOQoXruAJJ+nIU2rZ06/Ve5Cg2LAJOdpT22krM=";
        "1.9.2" = "sha256-jw36RM3VXC3yEa+muqOGpc2wb5uWEs5715OBEpdxD7w=";
        "1.9.3" = "sha256-GBtk4jyOP3AZHl167AfArQLJBJY2ey8xOKb7c/J+Bf8=";
        "1.9.4" = "sha256-NjtJeBTj23ESLmO0Z6PALkxw18E1zX5uka8Nd6Fy1WM=";
        "1.9.5" = "sha256-lthHmwBVunR565S/um7UBbC7dSGSJy7T6YJi0ai8ats=";
        "1.9.6" = "sha256-jsyqmOGGPRDkpfhh2OLsNJoj6IyxKtEPa295AirSu40=";
      };
    }
    {
      def = defs."1.10";
      releases = {
        "1.10" = "sha256-Lv69pd1k/VJZmhlWQEHWPcq6aPr6zACA/6bo8N+Nppc=";
        "1.10.1" = "sha256-smo0mWcrDt3L2HyOYd+2CudNnuDMGBpdkk+3PbYqJew=";
        "1.10.2" = "sha256-w4rJ/lPZSSsKCgKo5pHNLJbX9MwTrt7txtCGE7d+ZA8=";
        "1.10.3" = "sha256-6Yq0O7g5wxaWpCAuW2/ziLORZZ7yOHz5NlAZ+tF+Gtw=";
      };
    }
    {
      def = defs."1.11";
      releases = {
        "1.11" = "sha256-Karye+I1WQAqwAP1Oec8iFjO+tovHvPwW21E8oNAqsA=";
        "1.11.1" = "sha256-WxWdPA4KH4fecbaLy58aHEnp5xdJybcj8X4uHgKVx64=";
        "1.11.2" = "sha256-T0bR+TgMijUGKAdQ9jDp/JFcsaQ1tyS+VrSZ0BY2hxg=";
      };
    }
    {
      def = defs."1.11.3";
      releases = {
        "1.11.3" = "sha256-+eC+Jgwk72EiP+lhuoMP5Gr8Qh/A7fOGTbyItd42pSk=";
        "1.11.4" = "sha256-5SoDUWtUXMr117qgopkeKjLIunzyBYShhNQG8vuLaWA=";
        "1.11.5" = "sha256-iUsf16GNuGjO+1JG4zWhn3zbkil9IK7aNW6SHwmB86k=";
        "1.11.6" = "sha256-H/vGzEHw6myGT76UhbmBZ53F41D2xLxsNRL1pCJpNrU=";
      };
    }
    {
      def = defs."1.12";
      releases = {
        "1.12" = "sha256-T5IMrS3FnxvilrfXWE44KKNhVNFhkfPK1gpz5um8+Hk=";
        "1.12.1" = "sha256-MnUIabJKwqJXZSFf33XDSaq/lGXkNt4jUWAuGspcFz8=";
        "1.12.2" = "sha256-X7VukYGJs3eiI2jhm6r3AlK9hamWntX4qDc/Sej68H8=";
        "1.12.3" = "sha256-xCB7BXuXq3cb5htzuPhIwx+58MO7IEp/Gspbvv9B61o=";
        "1.12.4" = "sha256-UW8hjOX7DnkAWYfOxn0bw14BK3txUh6rNfpHx0Ft93I=";
        "1.12.5" = "sha256-NdrIJ3XxAN5GmYGM9i3aNBzWAgGJ5TRasUYYWfNQl8w=";
        "1.12.6" = "sha256-+DSrIUWx7iS9hTh5UARPXLQY3QryuExS5gwr8pFi2/o=";
        "1.13" = "sha256-CC2dlI1O2eUMWb9+7PWG7U6Ru3aXA3ebeI8ZfDqCcFw=";
        "1.13.1" = "sha256-bs1s9oLnjoMzYSZCY/D5SWlJv7rn+DZrwyfeOP8K0Ys=";
        "1.13.2" = "sha256-gGkhRzMzmd70EWrBln6S/qndJvKGcKNmAO/CdVZIpkY=";
        "1.13.3" = "sha256-gfnTlggbjIPrBUtGjObk9wAKSpfBeVbDFd7PqDCRNyQ=";
        "1.13.4" = "sha256-ic5JM/WbjwwgEVw5z+RQpZXMp07eJ7aIHojsJ3INHWY=";
        "1.14" = "sha256-4RiPXQdDdM8GlGyrsrnnC+4UFjeo/R+rmmYMiTD+gFk=";
        "1.14.1" = "sha256-qbTwS4tpysLoMqOKcYlDqpdtva0AlyEfizRIr9rPBmk=";
        "1.15" = "sha256-mQjHWqvUnRNmHW3LG8OCJS0izHe/czotVeh/KqLbhjY=";
        "1.15.1" = "sha256-r2ujkUIiBofFAPebSqLxgdmyTk+NjsSXzqS6JsZL7a8=";
        "1.16" = "sha256-+Y8tl7EYUcvnwtS06u9JiunRejwu8UAWCbe0ymZlW4o=";
        "1.16.1" = "sha256-XQW7OKI/0zErEK6pOED+7Ghb30pBFG54iChIFl066SE=";
        "1.16.2" = "sha256-zMRZ3j1xDgZqueEtLxGb0WSgjJNByiS6Ismtqhee7dA=";
        "1.16.3" = "sha256-/yv3ZWxNHG/do7i+uyHwkVOnNry6FpqvZeqyX6ETvzo=";
        "1.16.4" = "sha256-gPrMCYhaV+bUnQaXLArhCJxfqPTUx8/luupY5QhfE20=";
        "1.16.5" = "sha256-8B1YzW2dd/vcqetLvV6tGYgij9tz1veiAfX41rEYtGk=";
        "1.17" = "sha256-iSDB/EEeE7kL9wTvnbbynVQOdtIyyzssn03EzFmb2ZA=";
        "1.18" = "sha256-W9zMqWsAen40TCQgS5uawS7NF/WXGTGpBjve5Ih/Sq8=";
        "1.18.1" = "sha256-FoqjYyeDUbia9WaERI9SWlvOUHnQtoQr2RD90/FkaIc=";
        "1.19" = "sha256-4+LC46vzeJgTjbW2wdHcNckWDFl4vnlH0sdBcFJR1EU=";
      };
    }
  ];
  pname = "automake";
  canonical = tvpLib.packages.mkVersions {
    infra = {
      inherit (pkgs) lib fetchurl;
    };
    inherit pname versionTable;
    extraArgs.mkTests = pkgs.lib.makeOverridable (
      { pkgs }:
      package:
      import ./tests {
        inherit tvpLib package;
        pkgs = tvpLib.tests.withBase {
          inherit pkgs;
          base.stdenv = package.stdenv;
        };
      }
    ) { inherit pkgs; };
    packageMeta.upstream = {
      type = "directory-index";
      url = "https://mirrors.kernel.org/gnu/automake/";
      pattern = "automake-[0-9][^\"]*\\.tar\\.gz";
      normalise =
        file:
        if pkgs.lib.hasPrefix "automake-" file && pkgs.lib.hasSuffix ".tar.gz" file then
          pkgs.lib.removeSuffix ".tar.gz" (pkgs.lib.removePrefix "automake-" file)
        else
          null;
      include = version: builtins.match "[0-9]+(\\.[0-9]+)*(-p[0-9]+)?" version != null;
    };
  };
in
{
  inherit canonical;
  aliases = tvpLib.packages.mkAliases { inherit pname versionTable canonical; };
}
