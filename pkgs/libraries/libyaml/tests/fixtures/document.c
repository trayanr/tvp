#include <stdio.h>
#include <string.h>
#include <yaml.h>

int main(void)
{
    const char *input = "name: tvp\n";
    yaml_parser_t parser;
    yaml_document_t document;
    yaml_node_t *root;
    yaml_node_t *value;

    if (!yaml_parser_initialize(&parser))
        return 1;
    yaml_parser_set_input_string(&parser, (const unsigned char *)input, strlen(input));
    if (!yaml_parser_load(&parser, &document))
        return 1;

    root = yaml_document_get_root_node(&document);
    if (!root || root->type != YAML_MAPPING_NODE)
        return 1;
    value = yaml_document_get_node(&document, root->data.mapping.pairs.start[0].value);
    if (!value || value->type != YAML_SCALAR_NODE)
        return 1;
    printf("%s\n", (const char *)value->data.scalar.value);

    yaml_document_delete(&document);
    yaml_parser_delete(&parser);
    return 0;
}
