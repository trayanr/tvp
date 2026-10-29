#include <Python.h>
int main(void) {
    Py_Initialize();
    int result = PyRun_SimpleString("print(20 + 22)");
    Py_Finalize();
    return result;
}
