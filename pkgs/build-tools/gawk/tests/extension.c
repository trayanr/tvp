#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "gawkapi.h"

static const gawk_api_t *api;
static awk_ext_id_t ext_id;
static const char *ext_version = "TVP exact-header probe";
static awk_bool_t (*init_func)(void) = NULL;
int plugin_is_GPL_compatible;

static awk_value_t *
probe(int nargs, awk_value_t *result
#if gawk_api_major_version >= 2
      , struct awk_ext_func *unused
#endif
)
{
    return make_number(gawk_api_major_version, result);
}

static awk_ext_func_t func_table[] = {
#if gawk_api_major_version >= 2
    { "tvp_api", probe, 0, 0, awk_false, NULL },
#else
    { "tvp_api", probe, 0 },
#endif
};
dl_load_func(func_table, tvp_probe, "")
