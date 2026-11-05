#include <atomic>
#include <dlfcn.h>
#include <pthread.h>
#include <stdexcept>
#include <string>
#include <unistd.h>
#include <cstdio>
static std::atomic<int> ready{0}, destroyed{0};
static thread_local int tls = 7;
struct Guard { ~Guard() { ++destroyed; } };
static void *worker(void *) {
    Guard guard;
    if (tls++ != 7) return reinterpret_cast<void *>(1);
    ready.store(1);
    for (;;) { pthread_testcancel(); usleep(1000); }
}
int main(int argc, char **argv) {
    if (argc != 2) return 1;
    void *plugin = dlopen(argv[1], RTLD_NOW);
    if (!plugin) { std::puts(dlerror()); return 2; }
    auto raise = reinterpret_cast<void (*)()>(dlsym(plugin, "raise_exception"));
    auto count = reinterpret_cast<int (*)()>(dlsym(plugin, "destructor_count"));
    if (!raise || !count) return 3;
    try { raise(); return 4; }
    catch (const std::runtime_error &e) { if (std::string(e.what()) != "shared GNU ABI") return 5; }
    if (count() != 1 || dlclose(plugin)) return 6;
    pthread_t thread;
    void *result;
    if (pthread_create(&thread, nullptr, worker, nullptr)) return 7;
    while (!ready.load()) usleep(1000);
    if (pthread_cancel(thread) || pthread_join(thread, &result) || result != PTHREAD_CANCELED) return 8;
    if (destroyed.load() != 1 || tls != 7) return 9;
    std::puts("GNU shared C++ ABI/dlopen/exception/destructor; cancellation/forced unwind/TLS: PASS");
}
