{
  type = "directory-index";
  url = "https://mirrors.kernel.org/gnu/gawk/";
  # Capture complete hrefs before rejecting non-release filenames.
  pattern = ''href="[^"]+"'';
  normalise =
    file:
    let
      match = builtins.match ''href="gawk-([0-9]+(\.[0-9]+)*)\.tar\.(gz|bz2|xz|lz)"'' file;
    in
    if match == null then null else builtins.head match;
}
