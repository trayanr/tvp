export HOME="$PWD/home"
mkdir -p "$HOME" ext/tvp_owned lib
cat > ext/tvp_owned/extconf.rb <<'RUBY'
require 'mkmf'
create_makefile('tvp_owned')
RUBY
cat > ext/tvp_owned/tvp_owned.c <<'C'
#include <ruby.h>
static VALUE answer(VALUE self) { return INT2NUM(42); }
void Init_tvp_owned(void) { rb_define_singleton_method(rb_define_module("TvpOwned"), "answer", answer, 0); }
C
cat > tvp-owned.gemspec <<'RUBY'
Gem::Specification.new do |s|
  s.name = 'tvp-owned'; s.version = '1.0.0'; s.summary = 'Native owned consumer'
  s.authors = ['TVP']; s.files = Dir['ext/**/*']; s.extensions = ['ext/tvp_owned/extconf.rb']
end
RUBY
ruby -rrbconfig -e 'abort unless RbConfig::CONFIG["CC"] == "cc"; puts RbConfig::CONFIG["CFLAGS"]' >&2
cc --version >&2
gem build tvp-owned.gemspec > gem-build.log 2>&1
cat gem-build.log >&2
gem install --local --no-document --install-dir "$PWD/installed" tvp-owned-1.0.0.gem > gem-install.log 2>&1
cat gem-install.log >&2
GEM_HOME="$PWD/installed" GEM_PATH="$PWD/installed" ruby -rtvp_owned -e 'abort unless TvpOwned.answer == 42; abort unless Gem.loaded_specs["tvp-owned"].full_gem_path.start_with?(ARGV[0])' "$PWD/installed"
printf native-gem-ok
