#include <gettext-po.h>
#include <string.h>
int main(void) {
  po_file_t file = po_file_create();
  po_message_iterator_t it = po_message_iterator(file, NULL);
  po_message_t m = po_message_create();
  po_message_set_msgid(m, "Hello");
  po_message_set_msgstr(m, "Bonjour");
  po_message_insert(it, m);
  po_message_iterator_free(it);
  it = po_message_iterator(file, NULL);
  m = po_next_message(it);
  int failed = !m || strcmp(po_message_msgid(m), "Hello")
                 || strcmp(po_message_msgstr(m), "Bonjour")
                 || po_next_message(it) != NULL;
  po_message_iterator_free(it);
  po_file_free(file);
  return failed;
}
