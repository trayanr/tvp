package main
/*
#include <stdlib.h>
int answer(void) { char *p = malloc(1); if (!p) return 0; free(p); return 42; }
*/
import "C"
import "fmt"
func main() { fmt.Println(C.answer()) }
