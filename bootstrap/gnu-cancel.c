#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <unistd.h>
static atomic_int ready, cleaned;
static void cleanup(void *unused) { (void)unused; ++cleaned; }
static void *worker(void *unused) {
    (void)unused;
    pthread_cleanup_push(cleanup, 0);
    ready = 1;
    for (;;) { pthread_testcancel(); usleep(1000); }
    pthread_cleanup_pop(0);
    return 0;
}
int main(void) {
    pthread_t thread;
    void *result;
    if (pthread_create(&thread, 0, worker, 0)) return 1;
    while (!ready) usleep(1000);
    if (pthread_cancel(thread) || pthread_join(thread, &result)) return 2;
    if (result != PTHREAD_CANCELED || cleaned != 1) return 3;
    puts("GNU C-only cancellation/cleanup/unwinder: PASS");
}
