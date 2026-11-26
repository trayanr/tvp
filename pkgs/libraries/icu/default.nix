{ pkgs, tvp }:
let
  inherit (pkgs.lib) replaceStrings versionOlder;
  pname = "icu";
  project = "https://github.com/unicode-org/icu";
  # These releases have no ICU4C asset at the usual download URL.
  # Pin each official Git archive to the commit referenced by its release tag.
  legacyRevisions = {
    "50.1.2" = "c49438c8a6025afc8b4bc2eada580e27b9070226";
    "51.2" = "909df9d00b6bea0b971275692c38a9c9cbd12ea7";
    "52.1" = "7532b172ee963268015cce900f9cf90d13a8a739";
    "53.1" = "630bd3010ea6018d10e3ae91e7ae94ac08d0ebe4";
    "54.1" = "32d9621614f83d8ea78004254fb4230f5aa2caf4";
    "55.1" = "dd8356c7545a570b56136d3e44c62f7efdf5495f";
    "58.1" = "4f4208391a67752287ff4c73238bb91d33917c23";
  };
  versionTable = tvp.lib.packages.mkTable [
    {
      def.builder = ./build-4.8.2.nix;
      releases = {
        "4.8.2" = "sha256-THATG8uHIFYi7ZozSRdfKH0rZ38po4m0faRsblCyk3M=";
        "50.2" = "sha256-hzBvCIpMfACwraxrhOiGL++BwY+OxwpgywMlgGKQhEA=";
        "51.3" = "sha256-zcWPe0rGIgJ3Cj4p2edSboa/m436Ouv6CfgmPjFfPFg=";
        "52.2" = "sha256-FvkhEhBeYXDL+oNNV2ekp6WgKMDOz18+vX9NxGJW6oQ=";
        "53.2" = "sha256-srz2cyS3vjZGwRgWwMmr/+zwEhoLCr0xH9l9aFChyJo=";
        "54.2" = "sha256-sLfinVoGgCt7Qx6NPZgMav3y4lQOBxcXW8S/6UNB1pc=";
        "55.2" = "sha256-7aKqn5x4d0ii4tMQWQcgyovMYlKt9rTPsDtlvvnWZ1k=";
        "56.1" = "sha256-OmTpEFxzTc9jHAs+1gQEUxvObA9aZL/hpkAqTMIxSBY=";
        "56.2" = "sha256-GH+vSVEz9M/6ItYmiW5yiPQ9NC5q9euLIUob83utUaY=";
        "57.1" = "sha256-/4xny2WUmx54CPI1nyuA9yJpcEjpDnz8OC7B/iKelYE=";
        "57.2" = "sha256-Yj8EuSGCegQfQtUklab47uZWWpt1VwUaxo4JkSP/KNw=";
        "60.1" = "sha256-+PWmyPvzLAFaRnlyvbFHfcX11d/qkItu0hhxXute4iU=";
        "60.2" = "sha256-8HPqjzW5JtcLsz5ld1CKpkKosxaoA/Eb4grzhIEdtBg=";
        "60.3" = "sha256-R2KHsX224LfaIw3OS1jo5WabFRCEf4LKs2R5IPE3Q5A=";
        "61.1" = "sha256-0Af4muiiVDpTUlx0NZtls2QS+oSzNJ8UAL5tz0Cfr+8=";
        "61.2" = "sha256-y2qPjinwNVT4aPga5w09VoYTZgQwQHO+a96OddggeFU=";
      };
    }
    {
      def.builder = ./build-50.1.2.nix;
      releases = {
        "50.1.2" = "sha256-uj7Clzj6b6SCFXVcwP1gQTTePA39zl832BrcoJzZpso=";
        "51.2" = "sha256-699gK9lEwPtzrR0ex8DuCbzjniA/PL51pgMWYj5YCsE=";
        "52.1" = "sha256-DsbhA/Nl0QoIvAFO5NO/3NEJQHD7NBjyAnDqeQqUBM0=";
        "53.1" = "sha256-uMWE+kqKldQ4E2RuTNlAkfbX1/tl11cWjvTTIGhxTuw=";
        "54.1" = "sha256-7T/z0yrAu7rSbwqoasHNR1ry0q/I7Rj+PCBeQNOFEmY=";
        "55.1" = "sha256-nsvIdw9eCB8BpLJ+6fygSmAhAzMZfT1OoFA0JKn251g=";
      };
    }
    {
      def = {
        builder = ./build-50.1.2.nix;
        # These releases include xlocale.h when strtod_l is available.
        opts.needsLocaleHeader = true;
      };
      releases = {
        "58.1" = "sha256-B66Coi8JHtsG/QQ0Y/mHDMONWz/Bh+H/6UYtKi4TJTo=";
      };
    }
    {
      def = {
        builder = ./build-4.8.2.nix;
        # These releases include xlocale.h when strtod_l is available.
        opts.needsLocaleHeader = true;
      };
      releases = {
        "58.2" = "sha256-KwpEEBU6myDeDiDH2LZgSacq7yRLU2g9DXUhNxaD2gw=";
        "58.3" = "sha256-JoDzxUfNJsuh1+vYGc0zb/ks9ESicOGV/TsQv98iJ2w=";
        "59.1" = "sha256-cTL9r5N5Qp0AQAUhfxDgC30jGdD+oivf3e+JkcRbdf4=";
        "59.2" = "sha256-EHQWSEcKDtEG1fWIzFGgNXQlSEmyi8HELUwu7GKNcM0=";
      };
    }
    {
      def.builder = ./build.nix;
      releases = {
        "62.1" = "sha256-PdmGjWZjUN2mam4wXuzenUeftwsw1bVdeKHe/7l9WqM=";
        "62.2" = "sha256-9Rl25ok997COWU+nmBlvgM3wffiF/sEp9V96/ic7aQE=";
        "63.1" = "sha256-BcSQtpRU/OWGC36OKCEjFnSvChHX7y/r6poyUSmYy50=";
        "63.2" = "sha256-RnHphbXBElK/88I3SrhP1zxgnyYDu26yO4sVTGnqQhU=";
        "64.1" = "sha256-kvG3udUbOWZ5wX81ohEkIzYbjaPBud4AqpT9doriluY=";
        "64.2" = "sha256-Yn1dhHjm2W/IyQ/tSFEjkHmlYaaoueSLCJLyToLTHWw=";
        "65.1" = "sha256-U+N0ZrPW1tAerQKeNWfYc6Q6XRxmjtInjiU7aDE22Ug=";
        "66.1" = "sha256-UqPyIJq5VVnBzwoU8kM4AB84lhW/AOJYXvPbxD7PCi4=";
        "67.1" = "sha256-lKgM1vJRpTvSqZf28bWsZlP+eR36tm4esCJ3QPuG1dw=";
        "68.1" = "sha256-qfLj2LRDS45Th4tDCL0ebuUcnHBC4rGjdqvvtvuyny0=";
        "68.2" = "sha256-x5GT3uOQeiGZuClqk7UsXLdDMsJvPRZyaUh2gNR51iU=";
        "69.1" = "sha256-TLp7es0dPELES7DBS+ZjcJjH+vKzMM6Ha8XzuRXQl0U=";
        "70.1" = "sha256-jSBUKMF78Tu1NTAGae0oszihV7HAGuZtMdDT4tR8P9U=";
        "71.1" = "sha256-Z6fm5R9h+vEwa2k1Mz4TssSKvY2m0vRs5q3KJLHiHr8=";
        "72.1" = "sha256-otLTghcJKn7VZjXjRGf5L5drNw4gGCrTJe3qZoGnHWg=";
        "73.1" = "sha256-pFdDHeFktKp+ygDtE00A37+Ip3xphqEK53dPwHa7jEU=";
        "73.2" = "sha256-gYqAcS7TyqzZtlIwXgGvx/oWfm8ulJltpEuQwqtgTOE=";
        "74.1" = "sha256-hs6OYGgZcuYOTcskkMaXRj/Oxg3UAKX5v/uibQtSuNA=";
        "74.2" = "sha256-aNsIIhKpbW9T411g9H04uWLp+dIHp0z6x4Apro/14Iw=";
        "75.1" = "sha256-y5aN8+TS6H6LEcSaXQHHh70TuVRSgPxmQvgmUnYYyu8=";
        "76.1" = "sha256-36y0a/5HR0EEcs4+EUS/KKEC/uqk44dbrJtMbPMPTz4=";
        "77.1" = "sha256-WI5DH3cyfDkDH/u4hDwOO8EiwhE3RIX6h9xfP6/yQGE=";
        "78.1" = "sha256-Yhf1jKObIxJ2Bc/Gx+DTR1/ksNYxVwETg9cWy0FheIY=";
        "78.2" = "sha256-Pploe1xDXUsgljDi0uu3mQbJhGheeGNQeLZy4DyJ3zU=";
        "78.3" = "sha256-Oi56R2BLpwLzRYeDCOb+/sphLuiVz0pfIi55Vfq/4MA=";
        "79.1" = "sha256-Bvpj7LUhBI+AgvEq2Yj2tnjZDL2IqvziTLyUkCsZHZk=";
      };
    }
  ];
  family = tvp.lib.packages.mkFamily {
    inherit pname versionTable;
    source = tvp.lib.sources.archive {
      url =
        version:
        if builtins.hasAttr version legacyRevisions then
          "https://codeload.github.com/unicode-org/icu/tar.gz/${legacyRevisions.${version}}"
        # ICU 78 switched to dotted release tags and source asset names.
        else if versionOlder version "78" then
          "${project}/releases/download/release-${replaceStrings [ "." ] [ "-" ] version}/icu4c-${
            replaceStrings [ "." ] [ "_" ] version
          }-src.tgz"
        else
          "${project}/releases/download/release-${version}/icu4c-${version}-sources.tgz";
      discovery = {
        type = "git-tags";
        url = project;
        normalise =
          tag:
          let
            matched = builtins.match "release-([0-9]+([.-][0-9]+)+)" tag;
          in
          if matched == null then null else replaceStrings [ "-" ] [ "." ] (builtins.head matched);
      };
    };
    tests = import ./tests.nix;
    testDeps.pkg-config = tvp.packages.pkg-config;
  };
  canonical = tvp.lib.packages.mkVersions family;
in
{
  recipes.${pname} = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
