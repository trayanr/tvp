{ pkgs, tvp }:
{
  "3.1.0" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-UKBQTG7ctNYc5rjP292qlXBxlfqw7Ne16SZUsqlBKFQ=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.1" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-/m5Hgt6XRDl43bqLpL440iKqJNw+PwKmqOdwHA7rYZ0=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.2" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-YYQxEjifArc1QotTu2TPmIrZ+4GFi4JI4i5XM28kqD4=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.3" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-XqSYo19M0Vh1IApS3eQrbrF54SZOF9eHMsOlfNHGq54=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.4" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-o9VYeaDfqx1xQf3xDSKgfb+OXNxEFdob3gYSfVzDx7Y=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.5" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-NoXFHu7hNSwx6gOXBtcZdvU9AKttdzEt5qoauvXNosU=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.6" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-DQ2vuFnnZ2NDJXGjEJ0VN9l2JmvjCDRFZR3Gje7SXCI=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

  "3.1.7" = {
    builder = ../build-3.1.nix;
    sha256 = "sha256-BVas1p8UHdrOA/pd2NdufqDY9SMu3wEkKVebzaqzDns=";
    deps = {
      openssl = tvp.packages.openssl_3_5_7;
      readline = pkgs.readline;
      zlib = pkgs.zlib;
    };
  };

}
