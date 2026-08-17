#include <ruby.h>

static VALUE tvp_answer(VALUE self) {
  return INT2NUM(42);
}

void Init_tvp_ext(void) {
  VALUE mod = rb_define_module("TvpExt");
  rb_define_singleton_method(mod, "answer", tvp_answer, 0);
}
