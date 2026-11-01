#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <textstyle.h>
int main(int argc, char **argv) {
  if (argc != 2 || setenv("TERMINFO", argv[1], 1)
      || setenv("TERM", "xterm-256color", 1)) return 1;
  FILE *capture = tmpfile();
  if (!capture) return 2;
  term_ostream_t terminal = term_ostream_create(fileno(capture), "fixture", TTYCTL_NONE);
  /* The ANSI fallback without terminfo only knows eight colors. */
  term_color_t gray = term_ostream_rgb_to_color(terminal, 128, 128, 128);
  if (gray < 16) return 3;
  term_ostream_set_color(terminal, gray);
  ostream_write_str(terminal, "colored");
  term_ostream_set_color(terminal, COLOR_DEFAULT);
  ostream_flush(terminal, FLUSH_THIS_STREAM);
  ostream_free(terminal);
  if (fseek(capture, 0, SEEK_SET)) return 4;
  char buffer[256];
  size_t count = fread(buffer, 1, sizeof buffer - 1, capture);
  buffer[count] = '\0';
  if (!strstr(buffer, "\033[38;5;") || !strstr(buffer, "colored")) return 5;
  if (fclose(capture)) return 6;
  file_ostream_t out = file_ostream_create(stdout);
  ostream_write_str(out, "ok\n");
  ostream_flush(out, FLUSH_THIS_STREAM);
  ostream_free(out);
  return 0;
}
