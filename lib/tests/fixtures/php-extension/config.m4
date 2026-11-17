PHP_ARG_ENABLE([tvp_hello], [whether to enable tvp_hello],
  [AS_HELP_STRING([--enable-tvp_hello], [Enable the TVP extension fixture])], [yes])
if test "$PHP_TVP_HELLO" != "no"; then
  PHP_NEW_EXTENSION([tvp_hello], [tvp_hello.c], [$ext_shared])
fi
