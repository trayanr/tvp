#include <numa.h>
#include <unistd.h>

int main(void)
{
    long pagesize = sysconf(_SC_PAGESIZE);

    return pagesize > 0 && numa_pagesize() == pagesize ? 0 : 1;
}
