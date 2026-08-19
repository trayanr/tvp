/* cstdio first: 5.7's etip.h uses NULL without including anything defining it. */
#include <cstdio>
#include <cursesw.h>

int main()
{
	NCursesWindow::useColors();
	std::printf("cxx-ok");
	return 0;
}
