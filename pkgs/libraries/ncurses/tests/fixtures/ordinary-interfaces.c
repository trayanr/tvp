#define _XOPEN_SOURCE 700
#include <curses.h>
#include <form.h>
#include <menu.h>
#include <panel.h>
#include <wchar.h>
#include <stdio.h>
#include <stdlib.h>
int main(void) {
  FILE *sink = fopen("/dev/null", "w");
  SCREEN *screen = newterm("xterm", sink, stdin);
  if (!screen) return 1;
  WINDOW *w = newwin(4, 20, 0, 0);
  PANEL *p = new_panel(w);
  FIELD *fields[] = { new_field(1, 10, 0, 0, 0, 0), NULL };
  FORM *form = new_form(fields);
  ITEM *items[] = { new_item("choice", "description"), NULL };
  MENU *menu = new_menu(items);
  cchar_t cell;
  if (!w || !p || !fields[0] || !form || !items[0] || !menu) return 2;
  if (setcchar(&cell, L"A", A_NORMAL, 0, NULL) == ERR || wadd_wch(w, &cell) == ERR) return 3;
  if (set_field_buffer(fields[0], 0, "wide") != E_OK || set_menu_mark(menu, ">") != E_OK) return 4;
  free_menu(menu); free_item(items[0]); free_form(form); free_field(fields[0]);
  del_panel(p); delwin(w); endwin(); delscreen(screen); fclose(sink);
  puts("wide-form-menu-panel");
  return 0;
}
