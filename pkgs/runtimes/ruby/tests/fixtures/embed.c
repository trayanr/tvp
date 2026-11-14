#include <ruby.h>

int main(int argc, char **argv) {
    ruby_sysinit(&argc, &argv);
    RUBY_INIT_STACK;
    ruby_init();
    ruby_init_loadpath();
    rb_eval_string("print 6 * 7");
    return ruby_cleanup(0);
}
