# Check-only consumers of the public complete versioned recipes. Not aliases or
# ordinary variants: the parent decides when/where to activate this capability.
{
  tvp,
  candidate ? import ../. { },
}:
let
  base = candidate.withHardening {
    defaults = [
      "bindnow"
      "fortify"
      "format"
      "pic"
      "relro"
      "stackprotector"
      "strictoverflow"
    ];
  };
  zip = tvp.canonical.zip_3_0.override { inherit base; };
  unzip = tvp.canonical.unzip_6_0.override { inherit base; };
in
{
  inherit base zip unzip;
  zipTests = (zip.mkTests.override { inherit unzip; }) zip;
  unzipTests = (unzip.mkTests.override { inherit zip; }) unzip;
}
