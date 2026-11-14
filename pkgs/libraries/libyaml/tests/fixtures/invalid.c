#include <yaml.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  yaml_parser_t p; yaml_document_t d;
  const char *bad = "a: [unterminated";
  if (!yaml_parser_initialize(&p)) return 1;
  yaml_parser_set_input_string(&p, (const unsigned char *)bad, strlen(bad));
  int ok = yaml_parser_load(&p, &d);
  if (ok) yaml_document_delete(&d);
  int rejected = !ok && p.error == YAML_PARSER_ERROR && p.problem != NULL;
  yaml_parser_delete(&p);
  if (!rejected) return 2;
  puts("invalid-rejected"); return 0;
}
