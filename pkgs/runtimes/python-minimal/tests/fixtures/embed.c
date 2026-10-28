#include <Python.h>
int main(void) {
    Py_Initialize();
    int result = PyRun_SimpleString("print(20 + 22)");
    if (Py_FinalizeEx() < 0) return 120;
    return result;
}
