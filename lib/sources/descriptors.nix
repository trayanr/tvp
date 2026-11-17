# A source keeps immutable downloads and live release discovery together.
{ lib }:
let
  fail = message: throw "TVP source: ${message}";
  nonemptyString = value: builtins.isString value && value != "";
  discoveryMetadata =
    discovery:
    if discovery == null then
      null
    else if !builtins.isAttrs discovery then
      fail "discovery must be an attribute set or null"
    else if
      !(builtins.elem (discovery.type or null) [
        "directory-index"
        "git-tags"
        "git-head"
        "rubygems"
      ])
    then
      fail "unsupported discovery type"
    else if !nonemptyString (discovery.url or null) then
      fail "discovery requires a nonempty URL"
    else if discovery ? normalise && !builtins.isFunction discovery.normalise then
      fail "discovery.normalise must be a function"
    else if discovery ? include && !builtins.isFunction discovery.include then
      fail "discovery.include must be a function"
    else if discovery ? prefix then
      if discovery.type != "git-tags" || !builtins.isString discovery.prefix then
        fail "discovery.prefix is a string supported only for git-tags"
      else if discovery ? normalise then
        fail "choose discovery.prefix or discovery.normalise"
      else
        removeAttrs discovery [ "prefix" ]
        // {
          normalise =
            tag:
            if lib.hasPrefix discovery.prefix tag && tag != discovery.prefix then
              lib.removePrefix discovery.prefix tag
            else
              null;
        }
    else
      discovery;
  archiveSource =
    {
      url ? null,
      discovery ? null,
      fetch ? null,
    }:
    assert
      url == null
      || builtins.isString url
      || builtins.isFunction url
      || fail "download URL must be a string or version function";
    assert fetch == null || builtins.isFunction fetch || fail "fetch must be a source factory";
    assert url != null || fetch != null || fail "a download URL or fetch factory is required";
    let
      selectedURL =
        version:
        let
          value = if builtins.isFunction url then url version else url;
        in
        if value == null && fetch != null then
          null
        else if nonemptyString value then
          value
        else
          fail "download URL resolved to an empty or non-string value";
      configuredDiscovery = discoveryMetadata discovery;
    in
    # Validate discovery even when the caller only inspects the download URL.
    builtins.seq configuredDiscovery {
      __tvpSource = true;
      discovery = configuredDiscovery;
      describe =
        { version, ... }:
        let
          value = selectedURL version;
        in
        {
          type = "archive";
          url = if value == null then null else builtins.unsafeDiscardStringContext value;
        };
      __functor =
        _:
        { version, sha256 }@selection:
        if fetch != null then
          fetch selection
        else
          import <nix/fetchurl.nix> {
            url = selectedURL version;
            inherit sha256;
          };
    };
  directory =
    {
      url,
      archive,
      discovery ? { },
      fetch ? null,
    }:
    assert nonemptyString url && lib.hasSuffix "/" url || fail "directory URL must end in /";
    assert builtins.isString archive || fail "archive must be a filename template";
    assert
      discovery == null
      || builtins.isAttrs discovery
      || fail "discovery must be an attribute set or null";
    let
      parts = lib.splitString "{version}" archive;
      prefix = builtins.head parts;
      suffix = builtins.elemAt parts 1;
      validTemplate =
        builtins.length parts == 2
        && builtins.all (part: !lib.hasInfix part archive) [
          "/"
          "?"
          "#"
        ]
        && builtins.all (part: !lib.hasInfix part (prefix + suffix)) [
          "{"
          "}"
        ];
      versionPattern = "[0-9][A-Za-z0-9.+_-]*";
      archivePattern = lib.escapeRegex prefix + versionPattern + lib.escapeRegex suffix;
      defaults = {
        type = "directory-index";
        inherit url;
        pattern = "href=\"" + archivePattern + "\"";
        normalise =
          raw:
          let
            link = builtins.match ("href=\"(" + archivePattern + ")\"") raw;
            filename = if link == null then raw else builtins.head link;
            match = builtins.match (
              lib.escapeRegex prefix + "(" + versionPattern + ")" + lib.escapeRegex suffix
            ) filename;
          in
          if match == null then null else builtins.head match;
      };
    in
    assert validTemplate || fail "archive needs exactly one {version} in a plain filename";
    # An explicit discovery block can add a policy or replace an index location.
    # Null deliberately disables discovery while retaining a usable download.
    archiveSource {
      url = version: url + lib.replaceStrings [ "{version}" ] [ version ] archive;
      inherit fetch;
      discovery =
        if discovery == null then
          null
        else if (discovery.type or "directory-index") != "directory-index" then
          discovery
        else
          defaults // discovery;
    };
in
{
  archive = archiveSource;
  inherit directory;
}
