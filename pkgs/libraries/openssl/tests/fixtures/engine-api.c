#include <openssl/engine.h>
#include <string.h>

int main(void) {
    ENGINE *engine = ENGINE_new();
    if (!engine) return 1;
    if (!ENGINE_set_id(engine, "tvp-engine-api")) return 2;
    if (!ENGINE_set_name(engine, "TVP ENGINE interface")) return 3;
    if (strcmp(ENGINE_get_id(engine), "tvp-engine-api")) return 4;
    if (strcmp(ENGINE_get_name(engine), "TVP ENGINE interface")) return 5;
    ENGINE_free(engine);
    return 0;
}
