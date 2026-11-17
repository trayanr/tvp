# Pure download/discovery contracts. No network, realization or package builds.
{ lib }:
let
  sources = import ../sources { inherit lib; };
  selected = {
    version = "1.2.3";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  directory = sources.directory {
    url = "https://example.invalid/download/";
    archive = "lib++-{version}.tar.gz";
  };
  tags = sources.archive {
    url = version: "https://downloads.example.invalid/project-${version}.tar.xz";
    discovery = {
      type = "git-tags";
      url = "https://git.example.invalid/project.git";
      prefix = "v";
    };
  };
  source = _: builtins.toFile "source-descriptor-model" "source";
  custom = sources.archive { fetch = source; };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    sharedDirectory =
      directory.describe selected == {
        type = "archive";
        url = "https://example.invalid/download/lib++-1.2.3.tar.gz";
      }
      && directory.discovery.url == "https://example.invalid/download/"
      && directory.discovery.normalise "lib++-1.2.3.tar.gz" == "1.2.3"
      && directory.discovery.normalise "libXX-1.2.3.tar.gz" == null
      && directory.discovery.normalise "lib++-1.2.3.tar.gz.asc" == null
      && directory.discovery.normalise "lib++-latest.tar.gz" == null;
    selectedDownloadUnchanged =
      (directory selected).drvPath == (import <nix/fetchurl.nix> {
        url = "https://example.invalid/download/lib++-1.2.3.tar.gz";
        inherit (selected) sha256;
      }).drvPath;
    separateDiscovery =
      (tags.describe selected).url == "https://downloads.example.invalid/project-1.2.3.tar.xz"
      && tags.discovery.url == "https://git.example.invalid/project.git"
      && tags.discovery.normalise "v1.2.3" == "1.2.3"
      && tags.discovery.normalise "v" == null
      && tags.discovery.normalise "unrelated" == null
      && !(tags.discovery ? prefix);
    customFetchUnchanged = custom selected == source selected && (custom.describe selected).url == null;
    explicitUnknown = custom.discovery == null;
    alternateDiscoveryDoesNotInheritFilenameParser =
      let
        other = sources.directory {
          url = "https://example.invalid/";
          archive = "project-{version}.gem";
          discovery = {
            type = "rubygems";
            url = "https://example.invalid/versions.json";
          };
        };
      in
      !(other.discovery ? normalise)
      && !(other.discovery ? pattern)
      && other.discovery.type == "rubygems";
    disabledDiscovery =
      (sources.directory {
        url = "https://example.invalid/";
        archive = "project-{version}.tar.xz";
        discovery = null;
      }).discovery == null;
    badTemplates =
      builtins.all
        (
          template:
          rejects (
            sources.directory {
              url = "https://example.invalid/";
              archive = template;
            }
          )
        )
        [
          "project.tar.xz"
          "project-{version}-{version}.tar.xz"
          "../{version}.tar.xz"
          "project-{other}-{version}.tar.xz"
        ];
    badDirectory = rejects (
      sources.directory {
        url = "https://example.invalid";
        archive = "project-{version}.tar.xz";
      }
    );
    badURL = rejects ((sources.archive { url = _: null; }).describe selected);
    badDiscovery = rejects (
      sources.archive {
        url = "https://example.invalid/source";
        discovery.type = "unknown";
      }
    );
    ambiguousPrefix = rejects (
      sources.archive {
        url = "https://example.invalid/source";
        discovery = {
          type = "git-tags";
          url = "https://git.example.invalid/project.git";
          prefix = "v";
          normalise = value: value;
        };
      }
    );
  };
in
assert builtins.all (value: value) (builtins.attrValues results);
results
