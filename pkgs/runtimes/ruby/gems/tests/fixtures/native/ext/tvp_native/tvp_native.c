#include <ruby.h>

static VALUE answer(VALUE self)
{
    return INT2NUM(42);
}

void Init_tvp_native(void)
{
    VALUE fixture = rb_define_module("TvpNative");
    rb_define_singleton_method(fixture, "answer", answer, 0);
}
