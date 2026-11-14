# Common installed-path behavior, including bare compiled paths without fallback.
{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = [ deps.python ];
  libraries = [ package ];
  tests =
    {
      clean-paths = {
        script = ''
          unset PERL5LIB PERL5OPT PERLLIB
          perl -MConfig -MList::Util -e '
            for (@INC) { next if $_ eq "."; die "INC: $_" unless index($_,"${package}/lib/")==0 && index($_,chr(0))<0 }
            die unless $Config{prefix} eq "${package}";
            for(qw(privlib archlib)) { die unless index($Config{$_},"${package}/lib/")==0 }
            for(values %INC) { die "module: $_" unless index($_,"${package}/lib/")==0 }
            die unless $Config{useshrplib} eq "true";
            die unless $Config{cc} eq "${package.specification.base.compiler}/bin/cc";
            die unless $Config{make} eq "make";
            print "paths-ok";
          '
        '';
        expected = "paths-ok";
      };
    }
    // (
      if package.version == "5.24.4" then
        {
          dot-inc-relative-do = {
            script = ''
              unset PERL5LIB PERL5OPT PERLLIB
              printf '42;\n' > relative.pl
              perl -e 'die unless grep { $_ eq "." } @INC; my $v = do "relative.pl"; die unless $v == 42; print "dot-inc-ok"'
            '';
            expected = "dot-inc-ok";
          };
        }
      else
        { }
    );
}
