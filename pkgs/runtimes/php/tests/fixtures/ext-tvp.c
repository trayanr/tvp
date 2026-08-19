#include "php.h"

PHP_FUNCTION(tvp_answer)
{
  RETURN_LONG(42);
}

ZEND_BEGIN_ARG_INFO_EX(arginfo_tvp_answer, 0, 0, 0)
ZEND_END_ARG_INFO()

static const zend_function_entry tvp_functions[] = {
  PHP_FE(tvp_answer, arginfo_tvp_answer)
  PHP_FE_END
};

zend_module_entry tvp_module_entry = {
  STANDARD_MODULE_HEADER,
  "tvp",
  tvp_functions,
  NULL, NULL, NULL, NULL, NULL,
  "1.0",
  STANDARD_MODULE_PROPERTIES
};

ZEND_GET_MODULE(tvp)
