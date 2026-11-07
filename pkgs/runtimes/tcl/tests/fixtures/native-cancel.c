#include <tcl.h>
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <assert.h>
#include <string.h>
static atomic_int ready;
static void *worker(void *unused) {
    Tcl_Interp *interp = Tcl_CreateInterp();
    assert(interp && Tcl_Init(interp) == TCL_OK);
    assert(Tcl_Eval(interp, "expr {40+2}") == TCL_OK);
    assert(!strcmp(Tcl_GetStringResult(interp), "42"));
    Tcl_DeleteInterp(interp);
    Tcl_FinalizeThread();
    atomic_store(&ready, 1);
    for (;;) pthread_testcancel();
    return 0;
}
int main(int argc, char **argv) {
    Tcl_FindExecutable(argv[0]);
    pthread_t thread;
    assert(!pthread_create(&thread, 0, worker, 0));
    while (!atomic_load(&ready)) sched_yield();
    assert(!pthread_cancel(thread));
    void *result;
    assert(!pthread_join(thread, &result));
    assert(result == PTHREAD_CANCELED);
    Tcl_Finalize();
}
