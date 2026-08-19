#include <panel.h>
#include <stdio.h>

/* newterm against /dev/null rather than initscr: the build sandbox has no
   terminal, and the panel stack still needs a screen to exist. */
int main(void)
{
	FILE *out = fopen("/dev/null", "w");
	SCREEN *s = newterm("xterm", out, stdin);
	WINDOW *w = newwin(4, 10, 0, 0);
	PANEL *p = new_panel(w);
	int ok = p != NULL && panel_window(p) == w;

	del_panel(p);
	delwin(w);
	endwin();
	delscreen(s);
	printf("%s", ok ? "panel-ok" : "MISSING");
	return 0;
}
