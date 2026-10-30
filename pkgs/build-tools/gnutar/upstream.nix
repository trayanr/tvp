{
  type = "directory-index";
  url = "https://mirrors.kernel.org/gnu/tar/";
  # Capture complete href values and filename tokens before strict validation.
  pattern = "[^<>\"[:space:]]+";
  normalise =
    file:
    let
      match = builtins.match "tar-([0-9]+(\\.[0-9]+)+)\\.tar(\\.(gz|bz2|xz|lz))?" file;
    in
    if match == null then null else builtins.head match;
}
