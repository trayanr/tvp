#include <expat.h>
#include <stdio.h>
#include <string.h>
static int count;
static void start(void *ctx, const char *name, const char **attrs) { ++count; }
int main(void) {
  XML_Parser p=XML_ParserCreate(NULL);
  XML_SetElementHandler(p, start, NULL);
  const char *xml="<root><answer>42</answer></root>";
  if(XML_Parse(p,xml,(int)strlen(xml),1)!=XML_STATUS_OK || count!=2) return 1;
  XML_ParserFree(p);p=XML_ParserCreate(NULL);
  if(XML_Parse(p,"<broken>",8,1)!=XML_STATUS_ERROR) return 2;
  XML_ParserFree(p); puts(XML_ExpatVersion()+6); return 0;
}
