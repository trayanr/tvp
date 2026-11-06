#include <json-c/json.h>
#include <string.h>
int main(void) {
  struct json_object *o = json_tokener_parse("{\"n\":42}");
  struct json_object *n;
  int ok = json_object_object_get_ex(o, "n", &n) && json_object_get_int(n) == 42;
  json_object_put(o); return !ok;
}
