#include <json-c/json.h>
#include <json-c/json_pointer.h>
#include <json-c/json_patch.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

static void mark_destroyed(struct json_object *object, void *userdata)
{
    (void)object;
    ++*(int *)userdata;
}

int main(void)
{
    int destroyed = 0;
    struct json_object *root = json_tokener_parse("{\"items\":[1,2],\"name\":\"caf\u00e9\"}");
    struct json_object *items = NULL, *name = NULL, *parsed = NULL, *patch = NULL, *updated = NULL;
    struct json_tokener *tok = json_tokener_new();
    assert(root && tok);
    assert(json_pointer_get(root, "/items", &items) == 0);
    assert(json_object_array_length(items) == 2);
    assert(json_object_get_int(json_object_array_get_idx(items, 1)) == 2);
    assert(json_object_object_get_ex(root, "name", &name));
    json_object_set_userdata(name, &destroyed, mark_destroyed);
    json_object_get(name);
    parsed = json_tokener_parse(json_object_to_json_string_ext(root, JSON_C_TO_STRING_PLAIN));
    assert(parsed && json_object_equal(root, parsed));
    patch = json_tokener_parse("[{\"op\":\"add\",\"path\":\"/answer\",\"value\":42}]");
    assert(patch && json_patch_apply(parsed, patch, &updated, NULL) == 0);
    assert(json_pointer_get(updated, "/answer", &items) == 0);
    assert(json_object_get_int(items) == 42);
    json_object_put(updated);
    json_object_put(patch);
    json_object_put(parsed);
    json_object_put(root);
    assert(strcmp(json_object_get_string(name), "caf\u00e9") == 0);
    assert(destroyed == 0);
    json_object_put(name);
    assert(destroyed == 1);
    assert(json_tokener_parse_ex(tok, "{broken]", 8) == NULL);
    assert(json_tokener_get_error(tok) != json_tokener_success);
    assert(strcmp(json_tokener_error_desc(json_tokener_get_error(tok)), "success") != 0);
    json_tokener_free(tok);
    puts("ok");
    return 0;
}
