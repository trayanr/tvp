#include <stdio.h>
#include <gdbm.h>

int main(void)
{
  printf("%s\n", gdbm_version);
  return 0;
}
