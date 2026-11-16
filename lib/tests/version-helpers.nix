# Pure filename parsing contracts; no package selection, fetching or builds.
{ lib }:
let
  versions = import ../versions.nix { inherit lib; };
  parse = versions.fromArchiveName {
    prefix = "pkg-";
    suffixes = [
      ".tar.gz"
      ".tar.xz"
    ];
  };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  oldParser =
    { prefix, suffix }:
    file:
    if lib.hasPrefix prefix file && lib.hasSuffix suffix file then
      lib.removeSuffix suffix (lib.removePrefix prefix file)
    else
      null;
  # These are the exact archive parsers migrated from the family indexes.
  configurations =
    map
      (prefix: {
        inherit prefix;
        suffix = ".tar.gz";
      })
      [
        "autoconf-"
        "automake-"
        "bison-"
        "make-"
        "m4-"
        "pkg-config-"
        "gdbm-"
        "mpdecimal-"
        "ncurses-"
        "readline-"
        "perl-"
        "ruby-"
      ]
    ++ [
      {
        prefix = "binutils-";
        suffix = ".tar.xz";
      }
    ];
  results = {
    stable = parse "pkg-1.2.3.tar.gz" == "1.2.3";
    alternateArchive = parse "pkg-1.2.3.tar.xz" == "1.2.3";
    patchlevel = parse "pkg-1.8.7-p374.tar.gz" == "1.8.7-p374";
    prereleasePolicyIsSeparate = parse "pkg-2.0-rc1.tar.gz" == "2.0-rc1";
    movingAliasPolicyIsSeparate = parse "pkg-latest.tar.gz" == "latest";
    wrongPrefix = parse "other-1.2.3.tar.gz" == null;
    wrongSuffix = parse "pkg-1.2.3.zip" == null;
    trailingGarbage = parse "pkg-1.2.3.tar.gz.asc" == null;
    leadingGarbage = parse "mirror/pkg-1.2.3.tar.gz" == null;
    suffixIsCaseSensitive = parse "pkg-1.2.3.tar.GZ" == null;
    emptyFilename = parse "" == null;
    emptyExtraction = parse "pkg-.tar.gz" == "";
    literalMetacharacters =
      versions.fromArchiveName {
        prefix = "lib++-";
        suffixes = [ ".tar.gz" ];
      } "lib++-1.0.tar.gz" == "1.0";
    declaredSuffixOrder =
      versions.fromArchiveName {
        prefix = "pkg-";
        suffixes = [
          ".gz"
          ".tar.gz"
        ];
      } "pkg-1.0.tar.gz" == "1.0.tar";
    overlappingPrefixAndSuffix =
      versions.fromArchiveName {
        prefix = ".tar.gz";
        suffixes = [ ".tar.gz" ];
      } ".tar.gz" == "";
    oldParserEquivalence = builtins.all (
      configuration:
      let
        before = oldParser configuration;
        after = versions.fromArchiveName {
          inherit (configuration) prefix;
          suffixes = [ configuration.suffix ];
        };
        filenames = [
          ""
          "other-1.0${configuration.suffix}"
          "${configuration.prefix}1.0${configuration.suffix}"
          "${configuration.prefix}1.0-rc1${configuration.suffix}"
          "${configuration.prefix}1.8.7-p374${configuration.suffix}"
          "${configuration.prefix}latest${configuration.suffix}"
          "${configuration.prefix}${configuration.suffix}"
          "${configuration.prefix}1.0${configuration.suffix}.asc"
        ];
      in
      builtins.all (file: before file == after file) filenames
    ) configurations;
    rejectEmptyPrefix = rejects (
      versions.fromArchiveName {
        prefix = "";
        suffixes = [ ".gz" ];
      }
    );
    rejectNonstringPrefix = rejects (
      versions.fromArchiveName {
        prefix = 7;
        suffixes = [ ".gz" ];
      }
    );
    rejectMissingSuffixes = rejects (
      versions.fromArchiveName {
        prefix = "pkg-";
        suffixes = [ ];
      }
    );
    rejectNonlistSuffixes = rejects (
      versions.fromArchiveName {
        prefix = "pkg-";
        suffixes = ".gz";
      }
    );
    rejectEmptySuffix = rejects (
      versions.fromArchiveName {
        prefix = "pkg-";
        suffixes = [ "" ];
      }
    );
    rejectNonstringSuffix = rejects (
      versions.fromArchiveName {
        prefix = "pkg-";
        suffixes = [ null ];
      }
    );
    rejectNonstringFilename = rejects (parse null);
    canonicalNamesUnchanged = versions.attrName "ruby" "1.8.7-p374" == "ruby_1_8_7_p374";
  };
in
assert builtins.all (value: value) (builtins.attrValues results);
results
