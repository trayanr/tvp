#include <libxml/parser.h>
#include <libxml/tree.h>
#include <stdio.h>

int main(void)
{
	xmlDocPtr doc = xmlReadFile("doc.xml", NULL, 0);
	xmlNodePtr root = doc ? xmlDocGetRootElement(doc) : NULL;

	printf("%s", root ? (const char *)root->name : "MISSING");
	xmlFreeDoc(doc);
	xmlCleanupParser();
	return 0;
}
