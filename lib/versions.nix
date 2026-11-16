{ lib }:
{
  # "-" as well as ".", so patchlevel releases (1.8.7-p374) name consistently.
  attrName =
    pname: version:
    "${pname}_${
      lib.replaceStrings
        [
          "."
          "-"
        ]
        [
          "_"
          "_"
        ]
        version
    }";

  # Parse a literal archive name. Release/prerelease policy belongs to the
  # caller's include predicate, including whether an empty extraction is valid.
  fromArchiveName =
    { prefix, suffixes }:
    assert
      builtins.isString prefix && prefix != ""
      || throw "TVP archive version: prefix must be a nonempty string";
    assert
      builtins.isList suffixes
      && suffixes != [ ]
      && builtins.all (suffix: builtins.isString suffix && suffix != "") suffixes
      || throw "TVP archive version: suffixes must be a nonempty list of nonempty strings";
    file:
    assert builtins.isString file || throw "TVP archive version: filename must be a string";
    let
      matched = builtins.filter (suffix: lib.hasSuffix suffix file) suffixes;
    in
    if !lib.hasPrefix prefix file || matched == [ ] then
      null
    else
      lib.removeSuffix (builtins.head matched) (lib.removePrefix prefix file);
}
