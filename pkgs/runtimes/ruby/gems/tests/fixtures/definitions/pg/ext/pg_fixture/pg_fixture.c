#include <ruby.h>
#include <libpq-fe.h>

static VALUE marker(VALUE self)
{
    return INT2NUM(TVP_PG_PROVIDER_MARKER);
}

static VALUE client_version(VALUE self)
{
    return INT2NUM(PQlibVersion());
}

void Init_pg_fixture(void)
{
    VALUE fixture = rb_define_module("PgFixture");
    rb_define_singleton_method(fixture, "marker", marker, 0);
    rb_define_singleton_method(fixture, "client_version", client_version, 0);
}
