#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#if defined(ZLIB)
#include <zlib.h>
#elif defined(BZIP2)
#include <bzlib.h>
#elif defined(XZ)
#include <lzma.h>
#elif defined(ZSTD)
#include <zstd.h>
#endif
int main(void) {
 const char input[] = "source-owned codec roundtrip: \xc3\xa9 repeated repeated repeated";
 unsigned char packed[4096], output[4096];
 size_t len = sizeof input;
#if defined(ZLIB)
 uLongf n=sizeof packed, m=sizeof output;
 assert(compress2(packed,&n,(const Bytef*)input,len,9)==Z_OK);
 assert(uncompress(output,&m,packed,n)==Z_OK); assert(m==len);
#elif defined(BZIP2)
 unsigned n=sizeof packed,m=sizeof output;
 assert(BZ2_bzBuffToBuffCompress((char*)packed,&n,(char*)input,len,9,0,30)==BZ_OK);
 assert(BZ2_bzBuffToBuffDecompress((char*)output,&m,(char*)packed,n,0,0)==BZ_OK); assert(m==len);
#elif defined(XZ)
 size_t n=0, p=0, m=0; uint64_t limit=UINT64_MAX;
 assert(lzma_easy_buffer_encode(6,LZMA_CHECK_CRC64,NULL,(const uint8_t*)input,len,packed,&n,sizeof packed)==LZMA_OK);
 assert(lzma_stream_buffer_decode(&limit,0,NULL,packed,&p,n,output,&m,sizeof output)==LZMA_OK); assert(m==len);
 lzma_mt opts={0}; opts.threads=2; opts.preset=6; opts.check=LZMA_CHECK_CRC64;
 assert(lzma_stream_encoder_mt_memusage(&opts)!=UINT64_MAX);
#elif defined(ZSTD)
 size_t n=ZSTD_compress(packed,sizeof packed,input,len,3); assert(!ZSTD_isError(n));
 size_t m=ZSTD_decompress(output,sizeof output,packed,n); assert(!ZSTD_isError(m)); assert(m==len);
#endif
 assert(!memcmp(input,output,len));
 FILE *f=fopen("/proc/self/maps","r"); assert(f); char line[4096];
 while(fgets(line,sizeof line,f)) if(strstr(line,"/nix/store/")) fputs(line,stdout);
 fclose(f); puts("codec roundtrip PASS"); return 0;
}
