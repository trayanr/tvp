#include <fontconfig/fontconfig.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv) {
  if(argc!=2) return 1;
  FcConfig *config=FcConfigCreate();
  if(!FcConfigAppFontAddFile(config,(const FcChar8 *)argv[1])) return 2;
  FcPattern *pat=FcPatternCreate();FcObjectSet *os=FcObjectSetBuild(FC_FAMILY,NULL);
  FcFontSet *fonts=FcFontList(config,pat,os);FcChar8 *family;
  if(!fonts || fonts->nfont!=1 || FcPatternGetString(fonts->fonts[0],FC_FAMILY,0,&family)!=FcResultMatch || strcmp((char *)family,"TVP")) return 3;
  int v=FcGetVersion();printf("%d.%d.%d\n",v/10000,v/100%100,v%100);
  FcFontSetDestroy(fonts);FcObjectSetDestroy(os);FcPatternDestroy(pat);FcConfigDestroy(config);return 0;
}
