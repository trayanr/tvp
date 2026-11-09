#include <expat.h>
#include <stdio.h>
#include <string.h>
static char text[16];
static size_t used;
static void characters(void *context, const char *data, int length) {
  (void)context;
  if (length < 0 || used + (size_t)length >= sizeof text) return;
  memcpy(text + used, data, (size_t)length);
  used += (size_t)length;
  text[used] = 0;
}
int main(void) {
  const char *xml = "<!DOCTYPE r [<!ENTITY answer '42'>]><r>&answer;</r>";
  XML_Parser parser = XML_ParserCreate(NULL);
  if (!parser) return 1;
  XML_SetCharacterDataHandler(parser, characters);
  int ok = XML_Parse(parser, xml, (int)strlen(xml), XML_TRUE) == XML_STATUS_OK;
  XML_ParserFree(parser);
  if (!ok || strcmp(text, "42")) return 2;
  puts(text);
  return 0;
}
