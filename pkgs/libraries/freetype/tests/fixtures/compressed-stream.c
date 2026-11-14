#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_SYSTEM_H
#include FT_GZIP_H
#include FT_BZIP2_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static void *allocate(FT_Memory memory, long size) { (void)memory; return malloc(size); }
static void release(FT_Memory memory, void *block) { (void)memory; free(block); }
static void *resize(FT_Memory memory, long old, long size, void *block) { (void)memory; (void)old; return realloc(block,size); }
static unsigned char *load(const char *name, size_t *size) {
  FILE *f = fopen(name,"rb"); if (!f) return NULL;
  fseek(f,0,SEEK_END); *size=ftell(f); rewind(f);
  unsigned char *bytes=malloc(*size); if (!bytes || fread(bytes,1,*size,f)!=*size) exit(10);
  fclose(f); return bytes;
}
int main(int argc, char **argv) {
  if (argc != 4) return 1;
  size_t packed_size, size;
  unsigned char *packed=load(argv[2],&packed_size), *original=load(argv[3],&size), *decoded=malloc(size);
  if (!packed || !original || !decoded) return 2;
  struct FT_MemoryRec_ memory = {NULL, allocate, release, resize};
  FT_StreamRec source = {0}, stream = {0};
  source.base=packed; source.size=packed_size; source.memory=&memory;
  FT_Error error = !strcmp(argv[1],"gzip") ? FT_Stream_OpenGzip(&stream,&source) : FT_Stream_OpenBzip2(&stream,&source);
  if (error) { fprintf(stderr,"%s stream open: %d\n",argv[1],error); return 3; }
  /* Small gzip inputs become a memory stream; larger streams use callbacks. */
  if (stream.read) {
    if (stream.read(&stream,0,decoded,size)!=size) return 4;
  } else {
    if (!stream.base || stream.size < size) return 5;
    memcpy(decoded,stream.base,size);
  }
  if (memcmp(decoded,original,size)) return 6;
  if (stream.close) stream.close(&stream); free(packed); free(original); free(decoded);
  puts("compressed-stream-roundtrip"); return 0;
}
