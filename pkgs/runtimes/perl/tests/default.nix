# One suite, shared by every perl version. Never fork it per builder: a test
# that exists only for newer versions cannot detect drift in an older one.
# Guards select whole tests; they never edit a test body.
{
  pkgs,
  tvpLib,
  perl,
}:
let
  features = perl.passthru.tvp.features or { };
in
tvpLib.tests.mkSuite {
  inherit pkgs;
  package = perl;

  tests =
    {
      version = {
        script = ''
          perl -e 'printf "%vd", $^V'
        '';
        expected = perl.version;
      };

      # A core module that is compiled, not pure Perl — so this also proves the
      # XS loader and the architecture-specific lib directory line up.
      modules = {
        script = ''
          perl -MList::Util=sum -e 'print sum(1, 2, 39)'
        '';
        expected = "42";
      };

      regex = {
        script = ''
          perl -e '"tvp-1.2.3" =~ /(?<name>\w+)-(?<ver>[\d.]+)/ and print "$+{name} $+{ver}"'
        '';
        expected = "tvp 1.2.3";
      };

      unicode = {
        script = ''
          perl -e 'use utf8; binmode(STDOUT, ":utf8"); print length("tvpé")'
        '';
        expected = "4";
      };

      # A real file on disk run as a program, rather than -e, which is how every
      # consumer of a Perl actually invokes it.
      script = {
        script = ''
          cp ${./fixtures/script.pl} script.pl
          perl script.pl
        '';
        expected = "tvp nix preserves";
      };
    }

    # `glob` sat in File::Glob's @EXPORT_OK until 5.30 removed it, so
    # `use File::Glob "glob"` stopped compiling. That is the exact line in
    # OpenSSL's Configure which TVP patches out of 1.1.0g and earlier, so the
    # suite states the behaviour of every perl rather than only the modern one.
    // pkgs.lib.optionalAttrs (features.globImportable or false) {
      file-glob-importable = {
        script = ''
          perl -e 'use File::Glob "glob"; print defined &glob ? "importable" : "missing"'
        '';
        expected = "importable";
      };
    }

    // pkgs.lib.optionalAttrs (!(features.globImportable or false)) {
      file-glob-removed = {
        script = ''
          perl -e 'use File::Glob "glob"; print "importable"' 2>/dev/null || printf removed
        '';
        expected = "removed";
      };
    };
}
