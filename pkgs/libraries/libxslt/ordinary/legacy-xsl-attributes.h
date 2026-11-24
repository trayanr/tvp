#ifndef TVP_LIBXSLT_LEGACY_XSL_ATTRIBUTES_H
#define TVP_LIBXSLT_LEGACY_XSL_ATTRIBUTES_H

#include <libxml/tree.h>

/* Like libxslt 0.12's xsltGetNsProp, accept unqualified attributes
 * on elements in the requested namespace, as used by XSL instructions.
 */
static inline xmlChar *
tvpXsltGetNsProp(xmlNodePtr node, const xmlChar *name, const xmlChar *uri)
{
    xmlAttrPtr attr;

    if (node == NULL)
        return NULL;
    if (uri == NULL)
        return xmlGetProp(node, name);
    if (node->ns != NULL && xmlStrEqual(node->ns->href, uri)) {
        for (attr = node->properties; attr != NULL; attr = attr->next) {
            if (xmlStrEqual(attr->name, name) &&
                (attr->ns == NULL || xmlStrEqual(attr->ns->href, uri))) {
                xmlChar *value = xmlNodeListGetString(node->doc, attr->children, 1);
                return value != NULL ? value : xmlStrdup((const xmlChar *) "");
            }
        }
    }
    return xmlGetNsProp(node, name, uri);
}

#endif
