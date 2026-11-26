#include <ruby.h>

static VALUE answer(VALUE self) {
    return INT2NUM(TVP_TRANSITIVE_ANSWER);
}

void Init_tvp_transitive(void) {
    VALUE module = rb_define_module("TvpTransitive");
    rb_define_singleton_method(module, "answer", answer, 0);
}
