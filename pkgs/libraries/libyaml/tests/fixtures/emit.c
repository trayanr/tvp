#include <stdio.h>
#include <yaml.h>

static int step(yaml_emitter_t *emitter, yaml_event_t *event)
{
    return yaml_emitter_emit(emitter, event);
}

int main(void)
{
    yaml_emitter_t emitter;
    yaml_parser_t parser;
    yaml_event_t event;
    unsigned char buffer[512];
    size_t written = 0;
    int done = 0;

    if (!yaml_emitter_initialize(&emitter))
        return 1;
    yaml_emitter_set_output_string(&emitter, buffer, sizeof buffer, &written);

    yaml_stream_start_event_initialize(&event, YAML_UTF8_ENCODING);
    if (!step(&emitter, &event))
        return 1;
    yaml_document_start_event_initialize(&event, NULL, NULL, NULL, 1);
    if (!step(&emitter, &event))
        return 1;
    yaml_scalar_event_initialize(&event, NULL, NULL, (yaml_char_t *)"tvp", 3, 1, 1,
                                 YAML_PLAIN_SCALAR_STYLE);
    if (!step(&emitter, &event))
        return 1;
    yaml_document_end_event_initialize(&event, 1);
    if (!step(&emitter, &event))
        return 1;
    yaml_stream_end_event_initialize(&event);
    if (!step(&emitter, &event))
        return 1;
    yaml_emitter_delete(&emitter);

    /* Read the emitted bytes back rather than comparing them: 0.1.2 to 0.1.7
       write an explicit "..." document end that no other release does. */
    if (!yaml_parser_initialize(&parser))
        return 1;
    yaml_parser_set_input_string(&parser, buffer, written);

    while (!done) {
        if (!yaml_parser_parse(&parser, &event))
            return 1;
        if (event.type == YAML_SCALAR_EVENT)
            printf("%s\n", (const char *)event.data.scalar.value);
        done = event.type == YAML_STREAM_END_EVENT;
        yaml_event_delete(&event);
    }
    yaml_parser_delete(&parser);
    return 0;
}
