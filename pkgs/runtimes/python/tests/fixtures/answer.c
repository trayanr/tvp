#include <Python.h>
static PyObject *answer(PyObject *self, PyObject *args) { return PyLong_FromLong(42); }
static PyMethodDef methods[] = { {"answer", answer, METH_NOARGS, "Return 42."}, {NULL, NULL, 0, NULL} };
static struct PyModuleDef module = { PyModuleDef_HEAD_INIT, "answer", NULL, -1, methods };
PyMODINIT_FUNC PyInit_answer(void) { return PyModule_Create(&module); }
