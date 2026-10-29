#include <alsa/asoundlib.h>
#include <stdio.h>
int main(void) {
  snd_pcm_t *pcm;
  if(snd_pcm_open(&pcm,"null",SND_PCM_STREAM_PLAYBACK,0)<0) return 1;
  if(snd_pcm_set_params(pcm,SND_PCM_FORMAT_S16_LE,SND_PCM_ACCESS_RW_INTERLEAVED,2,48000,1,100000)<0) return 2;
  short samples[96]={0};if(snd_pcm_writei(pcm,samples,48)!=48) return 3;
  snd_pcm_close(pcm);puts(snd_asoundlib_version());return 0;
}
