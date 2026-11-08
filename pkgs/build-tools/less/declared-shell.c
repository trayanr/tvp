/* Less is single-threaded. Keep popen streams paired with their exact children,
 * and launch the declared shell directly instead of libc's ambient /bin/sh.
 * Link wrapping confines this adaptation to Less's own calls, not its libraries.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
static const char shell[] = "@TVP_SHELL@";
struct child { FILE *stream; pid_t pid; struct child *next; };
static struct child *children;

static int reap(pid_t pid)
{
    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) return -1;
    }
    return status;
}

FILE *__wrap_popen(const char *command, const char *mode)
{
    int descriptors[2], error, reading, child_fd, parent_fd, target;
    pid_t pid;
    FILE *stream;
    struct child *entry;
    posix_spawn_file_actions_t actions;
    char *argv[] = { (char *) shell, "-c", (char *) command, NULL };
    if (!mode || (mode[0] != 'r' && mode[0] != 'w') || mode[1]) {
        errno = EINVAL;
        return NULL;
    }
    entry = malloc(sizeof(*entry));
    if (!entry) return NULL;
    if (pipe2(descriptors, O_CLOEXEC)) { free(entry); return NULL; }
    reading = mode[0] == 'r';
    child_fd = descriptors[reading ? 1 : 0];
    parent_fd = descriptors[reading ? 0 : 1];
    target = reading ? STDOUT_FILENO : STDIN_FILENO;
    error = posix_spawn_file_actions_init(&actions);
    if (!error) {
        error = posix_spawn_file_actions_adddup2(&actions, child_fd, target);
        if (!error && child_fd != target)
            error = posix_spawn_file_actions_addclose(&actions, child_fd);
        if (!error)
            error = posix_spawn_file_actions_addclose(&actions, parent_fd);
        /* A child must not retain streams belonging to another popen call. */
        for (struct child *old = children; !error && old; old = old->next)
            if (fileno(old->stream) != target)
                error = posix_spawn_file_actions_addclose(&actions, fileno(old->stream));
        if (!error) error = posix_spawn(&pid, shell, &actions, NULL, argv, environ);
        posix_spawn_file_actions_destroy(&actions);
    }
    close(child_fd);
    if (error) { close(parent_fd); free(entry); errno = error; return NULL; }
    stream = fdopen(parent_fd, mode);
    if (!stream) {
        error = errno;
        close(parent_fd);
        kill(pid, SIGTERM);
        reap(pid);
        free(entry);
        errno = error;
        return NULL;
    }
    entry->stream = stream;
    entry->pid = pid;
    entry->next = children;
    children = entry;
    return stream;
}

int __wrap_pclose(FILE *stream)
{
    struct child **link = &children, *entry;
    int error, status;
    while (*link && (*link)->stream != stream) link = &(*link)->next;
    if (!*link) { errno = EINVAL; return -1; }
    entry = *link;
    *link = entry->next;
    error = fclose(stream) == EOF ? errno : 0;
    status = reap(entry->pid);
    free(entry);
    if (error) { errno = error; return -1; }
    return status;
}

int __wrap_system(const char *command)
{
    struct sigaction ignore = { .sa_handler = SIG_IGN }, oldint, oldquit;
    sigset_t blocked, oldmask, defaults;
    posix_spawnattr_t attributes;
    pid_t pid;
    int error, status;
    char *argv[] = { (char *) shell, "-c", (char *) command, NULL };
    if (!command) return access(shell, X_OK) == 0;
    sigemptyset(&ignore.sa_mask);
    sigaction(SIGINT, &ignore, &oldint);
    sigaction(SIGQUIT, &ignore, &oldquit);
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGCHLD);
    sigprocmask(SIG_BLOCK, &blocked, &oldmask);
    sigemptyset(&defaults);
    if (oldint.sa_handler != SIG_IGN) sigaddset(&defaults, SIGINT);
    if (oldquit.sa_handler != SIG_IGN) sigaddset(&defaults, SIGQUIT);
    error = posix_spawnattr_init(&attributes);
    if (!error) {
        error = posix_spawnattr_setsigmask(&attributes, &oldmask);
        if (!error) error = posix_spawnattr_setsigdefault(&attributes, &defaults);
        if (!error) error = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF);
        if (!error) error = posix_spawn(&pid, shell, NULL, &attributes, argv, environ);
        posix_spawnattr_destroy(&attributes);
    }
    status = error ? -1 : reap(pid);
    sigaction(SIGINT, &oldint, NULL);
    sigaction(SIGQUIT, &oldquit, NULL);
    sigprocmask(SIG_SETMASK, &oldmask, NULL);
    if (error) errno = error;
    return status;
}
