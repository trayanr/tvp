#include <yaml.h>
#include <stdio.h>
#include <string.h>
int main(void) {
  yaml_parser_t p; yaml_event_t e;
  const char *bad = "a: [unterminated";
  int accepted = 1, done = 0;
  if (!yaml_parser_initialize(&p)) return 1;
  yaml_parser_set_input_string(&p, (const unsigned char *)bad, strlen(bad));
  while (!done) {
    if (!yaml_parser_parse(&p, &e)) { accepted = 0; break; }
    done = e.type == YAML_STREAM_END_EVENT;
    yaml_event_delete(&e);
  }
  int rejected = !accepted && p.error == YAML_PARSER_ERROR && p.problem != NULL;
  yaml_parser_delete(&p);
  if (!rejected) return 2;
  puts("invalid-rejected"); return 0;
}
