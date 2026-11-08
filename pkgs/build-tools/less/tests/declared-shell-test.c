#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

static void exit_code(int status, int expected)
{
    assert(WIFEXITED(status) && WEXITSTATUS(status) == expected);
}
int main(void)
{
    char text[16] = {0};
    FILE *a = popen("printf first", "r");
    FILE *b = popen("printf second", "r");
    assert(a && b);
    assert(fread(text, 1, 5, a) == 5 && !memcmp(text, "first", 5));
    exit_code(pclose(a), 0);
    assert(fread(text, 1, 6, b) == 6 && !memcmp(text, "second", 6));
    exit_code(pclose(b), 0);
    a = popen("read word; test \"$word\" = written", "w");
    assert(a && fputs("written\n", a) >= 0);
    exit_code(pclose(a), 0);
    a = popen("exit 7", "r");
    assert(a); exit_code(pclose(a), 7);
    a = popen("kill -TERM $$", "r");
    assert(a);
    int status = pclose(a);
    assert(WIFSIGNALED(status) && WTERMSIG(status) == SIGTERM);
    signal(SIGINT, SIG_DFL);
    exit_code(system("exit 9"), 9);
    status = system("kill -INT $$");
    assert(WIFSIGNALED(status) && WTERMSIG(status) == SIGINT);
    struct sigaction action;
    assert(sigaction(SIGINT, NULL, &action) == 0 && action.sa_handler == SIG_DFL);
    assert(system(NULL));
    assert(popen("exit 0", "x") == NULL && errno == EINVAL);
    assert(waitpid(-1, &status, WNOHANG) == -1 && errno == ECHILD);
    puts("streams, statuses, signals and reaping");
    return 0;
}
