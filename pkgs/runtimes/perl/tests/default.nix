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

      cwd = {
        script = ''
          perl <<'PERL'
          use strict;
          use warnings;
          use Cwd ();
          my $root = Cwd::getcwd();
          mkdir "real directory" or die "mkdir: $!";
          symlink "real directory", "alias directory" or die "symlink: $!";
          chdir "alias directory" or die "chdir: $!";
          $ENV{PWD} = "/nonexistent/logical/directory";
          $ENV{PATH} = "";
          my $expected = "$root/real directory";
          die "cwd mismatch" unless Cwd::cwd() eq $expected;
          die "getcwd mismatch" unless Cwd::getcwd() eq $expected;
          die "abs_path mismatch" unless Cwd::abs_path(".") eq $expected;
          die "symlink resolution mismatch"
            unless Cwd::abs_path("../alias directory") eq $expected;
          print "cwd-ok";
          PERL
        '';
        expected = "cwd-ok";
      };

      # Exercise the installed shared libperl ABI, not only its interpreter.
      # A failed ELF probe can otherwise select the obsolete a.out format.
      shared-embed = {
        script = ''
          cat > embed.c <<'C'
          #include <EXTERN.h>
          #include <perl.h>
          EXTERN_C void xs_init(pTHX);
          static PerlInterpreter *my_perl;
          int main(int argc, char **argv, char **env) {
            char *program[] = { "", "-e", "use List::Util qw(sum); print sum(1,2,39)" };
            PERL_SYS_INIT3(&argc, &argv, &env);
            my_perl = perl_alloc();
            perl_construct(my_perl);
            int result = perl_parse(my_perl, xs_init, 3, program, NULL);
            if (!result) result = perl_run(my_perl);
            perl_destruct(my_perl);
            perl_free(my_perl);
            PERL_SYS_TERM();
            return result;
          }
          C
          perl -MExtUtils::Embed -e xsinit
          $CC embed.c perlxsi.c $(perl -MExtUtils::Embed -e ccopts -e ldopts) -o embed
          readelf -d embed | grep -q 'NEEDED.*libperl\.so'
          ./embed
        '';
        expected = "42";
      };

      sdbm = {
        script = ''
          perl -MSDBM_File -MFcntl=O_RDWR,O_CREAT -e '
            tie my %db, "SDBM_File", "roundtrip", O_RDWR|O_CREAT, 0600 or die $!;
            $db{answer} = 42;
            untie %db;
            tie %db, "SDBM_File", "roundtrip", O_RDWR, 0600 or die $!;
            print $db{answer};
            untie %db;
          '
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

    // pkgs.lib.optionalAttrs ((perl.passthru.tvp.deps or { }) ? coreutils) {
      # These releases embed an external pwd in installed Cwd.pm for miniperl
      # and the non-XS fallback. Invoke it directly: the normal XS getcwd path
      # alone cannot detect a missing runtime executable in the sandbox.
      cwd-pwd-fallback = {
        script = ''
          test ! -x /bin/pwd
          test ! -x /usr/bin/pwd
          test ! -x /QOpenSys/bin/pwd
          perl <<'PERL'
          use strict;
          use warnings;
          use Cwd ();
          my $root = Cwd::getcwd();
          mkdir "real directory" or die "mkdir: $!";
          symlink "real directory", "alias directory" or die "symlink: $!";
          chdir "alias directory" or die "chdir: $!";
          $ENV{PWD} = "/nonexistent/logical/directory";
          $ENV{PATH} = "";
          local $/;
          my $actual = Cwd::_backtick_pwd();
          die "external pwd fallback mismatch"
            unless defined($actual) && $actual eq "$root/real directory";
          print "cwd-pwd-fallback-ok";
          PERL
        '';
        expected = "cwd-pwd-fallback-ok";
      };
    }

    // pkgs.lib.optionalAttrs (features.legacyCompilerProbes or false) {
      # ExtUtils::Embed and XS consumers inherit these installed compiler flags.
      compiler-options = {
        script = ''
          perl -MConfig -e '
            my $flags = " $Config{ccflags} ";
            die "missing aliasing safety flag" unless $flags =~ /\s-fno-strict-aliasing\s/;
            die "obsolete structure-return ABI" if $flags =~ /\s-fpcc-struct-return\s/;
            print "compiler-options-ok";
          '
        '';
        expected = "compiler-options-ok";
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
