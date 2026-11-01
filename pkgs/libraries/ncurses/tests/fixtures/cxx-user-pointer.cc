#include <cstdio>
#include <unistd.h>
#include <cursesp.h>
#include <cursesf.h>
#include <cursesm.h>

/* Consumers read user data through const views of the historical wrappers. */
void *form_data(const NCursesUserForm<void>& form) { return form.UserData(); }
void *menu_data(const NCursesUserMenu<void>& menu) { return menu.UserData(); }

int main()
{
    FILE *report = fdopen(dup(fileno(stdout)), "w");
    if (!report || !freopen("/dev/null", "w", stdout)) return 1;
    bool ok;
    {
        int payload = 42;
        NCursesUserPanel<void> panel(4, 10, 0, 0, &payload);
        const NCursesUserPanel<void>& view = panel;
        ok = view.UserData() == &payload;
        panel.setUserData(0);
        ok = ok && view.UserData() == 0;
    }
    std::fprintf(report, "%s", ok ? "user-pointer-ok" : "MISSING");
    std::fclose(report);
    return ok ? 0 : 1;
}
