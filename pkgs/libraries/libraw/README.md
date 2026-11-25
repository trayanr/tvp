# LibRaw build features

The default package installs both LibRaw libraries, their pkg-config
interfaces and the upstream sample utilities. OpenMP, JPEG and Zlib decoding,
the Sigma X3F decoder and Raspberry Pi Bayer decoding are enabled.

The `lcms2` builder argument accepts a source-owned LittleCMS 2 provider
for color profile processing. The standalone recipe can enable it once that
provider lands. RawSpeed, Adobe DNG SDK and GoPro GPR SDK integrations need
their own providers and build wiring.
