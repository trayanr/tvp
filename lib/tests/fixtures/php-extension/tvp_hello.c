#include <php.h>

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_tvp_hello, 0, 0, IS_STRING, 0)
ZEND_END_ARG_INFO()

PHP_FUNCTION(tvp_hello) {
    ZEND_PARSE_PARAMETERS_NONE();
    RETURN_STRING("custom-extension-ok");
}

static const zend_function_entry functions[] = {
    PHP_FE(tvp_hello, arginfo_tvp_hello)
    PHP_FE_END
};

zend_module_entry tvp_hello_module_entry = {
    STANDARD_MODULE_HEADER,
    "tvp_hello", functions,
    NULL, NULL, NULL, NULL, NULL,
    "1.0.0",
    STANDARD_MODULE_PROPERTIES
};

ZEND_GET_MODULE(tvp_hello)
