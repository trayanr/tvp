# Gawk 5.4.1's upstream Unicode and charset fixtures name these locales.
# Generate their data with the matching owned libc; no legacy locale archive.
{
  builder,
  base,
  bash,
  coreutils,
  tar,
  xz,
  libc,
}:
builder {
  recipe =
    { src, libc }:
    final: {
      pname = "gawk-check-locales";
      version = "2.39";
      inherit
        base
        bash
        coreutils
        src
        ;
      plan = [
        (
          (base.environment {
            tools = [
              tar
              xz
              libc
            ];
          })
          // {
            name = "locales.generate";
            run = ''
              ${tar}/bin/tar -xJf ${final.src} glibc-2.39/localedata
              mkdir -p "$out"
              export I18NPATH="$PWD/glibc-2.39/localedata"
              for language in en_US fr_FR ru_RU ja_JP; do
                ${libc}/bin/localedef --no-archive -i "$language" -f "$I18NPATH/charmaps/UTF-8" "$out/$language.UTF-8"
              done
              ${libc}/bin/localedef --no-archive -i el_GR -f "$I18NPATH/charmaps/ISO-8859-7" "$out/el_GR.iso88597@euro"
              for language in en_US fr_FR ru_RU ja_JP; do
                test "$(LOCPATH="$out" LC_ALL=$language.UTF-8 ${libc}/bin/locale charmap)" = UTF-8
              done
            '';
          }
        )
      ];
    };
  args = {
    inherit
      libc
      base
      bash
      coreutils
      tar
      xz
      ;
    src = import <nix/fetchurl.nix> {
      url = "https://mirrors.kernel.org/gnu/glibc/glibc-2.39.tar.xz";
      sha256 = "sha256-93vUfPgXDFc2Wue/hmlsEYrbOxINMlnGTFAtPcHi2SY=";
    };
  };
  dependencyNames = [
    "libc"
    "bash"
    "coreutils"
    "tar"
    "xz"
  ];
  metadata.kind = "owned-test-support";
  selection.kind = "owned-test-support";
  mkTests = _: { };
}
