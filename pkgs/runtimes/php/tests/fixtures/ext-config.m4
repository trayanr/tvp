PHP_ARG_ENABLE([tvp], [whether to enable tvp], [  --enable-tvp  Enable tvp])
if test "$PHP_TVP" != "no"; then
  PHP_NEW_EXTENSION(tvp, tvp.c, $ext_shared)
fi
