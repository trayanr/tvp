#include <alsa/asoundlib.h>
#include <alsa/topology.h>
#include <stdio.h>
#include <stdlib.h>
int main(void) {
  snd_tplg_t *writer = snd_tplg_new(), *reader = snd_tplg_new();
  void *binary = NULL; size_t size = 0;
  if (!writer || !reader) return 1;
  if (snd_tplg_set_version(writer, 17) || snd_tplg_set_manifest_data(writer, "TVP", 3)) return 2;
  if (snd_tplg_build_bin(writer, &binary, &size) || size < 16) return 3;
  if (snd_tplg_decode(reader, binary, size, 0)) return 4;
  free(binary); snd_tplg_free(writer); snd_tplg_free(reader);
  puts("topology-binary-roundtrip"); return 0;
}
