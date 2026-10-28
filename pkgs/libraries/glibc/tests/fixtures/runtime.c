#define _GNU_SOURCE
#include <gnu/libc-version.h>
#include <dlfcn.h>
#include <execinfo.h>
#include <locale.h>
#include <netdb.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static void *worker(void *arg) {
    for (;;) { pthread_testcancel(); usleep(1000); }
    return arg;
}
int main(int argc, char **argv) {
    if (argc != 2 || strcmp(gnu_get_libc_version(), argv[1])) return 1;
    if (!setlocale(LC_ALL, "C.UTF-8")) return 2;
    void *frames[16];
    if (backtrace(frames, 16) < 1) return 3;
    pthread_t thread;
    void *result;
    if (pthread_create(&thread, NULL, worker, NULL)) return 4;
    if (pthread_cancel(thread) || pthread_join(thread, &result) || result != PTHREAD_CANCELED) return 5;
    void *handle = dlopen("libm.so.6", RTLD_NOW);
    if (!handle) { fputs(dlerror(), stderr); return 6; }
    double (*square_root)(double) = dlsym(handle, "sqrt");
    if (!square_root || square_root(144.0) != 12.0) return 7;
    dlclose(handle);
    struct addrinfo hints = { .ai_family = AF_INET, .ai_flags = AI_NUMERICHOST };
    struct addrinfo *addresses = NULL;
    if (getaddrinfo("127.0.0.1", NULL, &hints, &addresses)) return 8;
    freeaddrinfo(addresses);
    puts("ok");
    return 0;
}
