#include <ft2build.h>
#include FT_FREETYPE_H
#include <stdio.h>
int main(int argc,char **argv) {
  FT_Library lib;FT_Face face;FT_Int a,b,c;
  if(argc!=2 || FT_Init_FreeType(&lib) || FT_New_Face(lib,argv[1],0,&face)) return 1;
  if(FT_Select_Size(face,0) || FT_Load_Char(face,'A',FT_LOAD_RENDER)) return 2;
  unsigned n=0;for(unsigned i=0;i<face->glyph->bitmap.rows*face->glyph->bitmap.pitch;i++) n+=face->glyph->bitmap.buffer[i];
  if(!n) return 3;
  FT_Library_Version(lib,&a,&b,&c);printf("%d.%d.%d\n",a,b,c);
  FT_Done_Face(face);FT_Done_FreeType(lib);return 0;
}
