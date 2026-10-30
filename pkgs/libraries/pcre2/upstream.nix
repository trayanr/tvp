{
  type = "git-tags";
  url = "https://github.com/PCRE2Project/pcre2";
  normalise =
    tag:
    let
      match = builtins.match "pcre2-([0-9]+[.][0-9]+)" tag;
    in
    if match == null then null else builtins.head match;
}
