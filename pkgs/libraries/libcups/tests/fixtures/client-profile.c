#include <cups/cups.h>
#include <cups/http.h>
#include <cups/raster.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(void) {
  char scheme[32], user[32], host[128], resource[128]; int port;
  if (httpSeparateURI(HTTP_URI_CODING_ALL, "ipps://localhost:8631/printers/tvp", scheme, sizeof scheme, user, sizeof user, host, sizeof host, &port, resource, sizeof resource) != HTTP_URI_STATUS_OK) return 1;
  if (strcmp(scheme,"ipps") || port != 8631 || strcmp(resource,"/printers/tvp")) return 2;
  cups_option_t *options = NULL;
  int count = cupsParseOptions("media=A4 sides=two-sided-long-edge", 0, &options);
  if (count != 2 || strcmp(cupsGetOption("media", count, options),"A4")) return 3;
  cupsFreeOptions(count, options);
  int fd = open("raster", O_CREAT | O_TRUNC | O_RDWR, 0600);
  if (fd < 0) return 4;
  cups_page_header2_t header; memset(&header,0,sizeof header);
  header.cupsWidth = 8; header.cupsHeight = 1; header.cupsBitsPerColor = 8;
  header.cupsBitsPerPixel = 8; header.cupsBytesPerLine = 8;
  header.cupsColorOrder = CUPS_ORDER_CHUNKED; header.cupsColorSpace = CUPS_CSPACE_W;
  header.cupsNumColors = 1;
  unsigned char pixels[8] = {0,32,64,96,128,160,192,255}, result[8];
  cups_raster_t *r = cupsRasterOpen(fd, CUPS_RASTER_WRITE);
  if (!r || !cupsRasterWriteHeader2(r,&header) || cupsRasterWritePixels(r,pixels,8) != 8) return 5;
  cupsRasterClose(r); lseek(fd,0,SEEK_SET);
  r = cupsRasterOpen(fd, CUPS_RASTER_READ);
  if (!r || !cupsRasterReadHeader2(r,&header) || header.cupsWidth != 8 || cupsRasterReadPixels(r,result,8) != 8 || memcmp(result,pixels,8)) return 6;
  cupsRasterClose(r); close(fd);
  puts("uri-options-raster"); return 0;
}
