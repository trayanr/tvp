#include <stdio.h>
#include <string.h>
#include <yaml.h>

int main(void)
{
    const char *input = "north: star\nname: tvp\n";
    yaml_parser_t parser;
    yaml_event_t event;
    int done = 0;
    int first = 1;

    if (!yaml_parser_initialize(&parser))
        return 1;
    yaml_parser_set_input_string(&parser, (const unsigned char *)input, strlen(input));

    while (!done) {
        if (!yaml_parser_parse(&parser, &event))
            return 1;
        if (event.type == YAML_SCALAR_EVENT) {
            if (!first)
                putchar(' ');
            fputs((const char *)event.data.scalar.value, stdout);
            first = 0;
        }
        done = event.type == YAML_STREAM_END_EVENT;
        yaml_event_delete(&event);
    }

    yaml_parser_delete(&parser);
    putchar('\n');
    return 0;
}
