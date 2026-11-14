#include <string.h>
#include <gnumake.h>
int plugin_is_GPL_compatible;
static char *answer(const char *name, unsigned int argc, char **argv) {
  char *s = gmk_alloc(3);
  (void)name; (void)argc; (void)argv;
  memcpy(s, "42", 3);
  return s;
}
int module_gmk_setup(const gmk_floc *location) {
  (void)location;
  gmk_add_function("tvp_answer", answer, 0, 1, GMK_FUNC_DEFAULT);
  return 1;
}
