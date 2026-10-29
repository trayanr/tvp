#include <cups/cups.h>
#include <stdio.h>
int main(void) {
  ipp_t *request=ippNewRequest(IPP_OP_GET_PRINTER_ATTRIBUTES);
  ippAddString(request,IPP_TAG_OPERATION,IPP_TAG_URI,"printer-uri",NULL,"ipp://localhost/printers/tvp");
  if(!ippFindAttribute(request,"printer-uri",IPP_TAG_URI) || ippLength(request)<40) return 1;
  ippDelete(request);printf("%d.%d.%d\n",CUPS_VERSION_MAJOR,CUPS_VERSION_MINOR,CUPS_VERSION_PATCH);return 0;
}
