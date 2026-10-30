#include <bits/c++config.h>
#include <link.h>
#include <span>
#include <string_view>
#include <iostream>

static_assert(_GLIBCXX_RELEASE == 16);

static int loaded(struct dl_phdr_info *info, size_t, void *path)
{
    std::string_view name(info->dlpi_name);
    if (name.find("libstdc++.so") != std::string_view::npos)
        *static_cast<std::string_view *>(path) = name;
    return 0;
}

int main()
{
    int values[] = {20, 22};
    std::span<int> view(values);
    std::string_view path;
    dl_iterate_phdr(loaded, &path);
    std::cout << view[0] + view[1] << '\n' << path << '\n';
}
