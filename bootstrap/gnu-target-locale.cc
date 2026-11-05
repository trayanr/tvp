#include <climits>
#include <locale>
#include <stdexcept>
#include <string>
#include <cwchar>
#include <clocale>
#include <thread>
#include <vector>
#include <numeric>
#include "gnu-target-maps.h"
int main() {
    if (!std::setlocale(LC_ALL, "C.UTF-8")) return 1;
    std::locale loc("C.UTF-8");
    auto &facet = std::use_facet<std::ctype<wchar_t>>(loc);
    if (!facet.is(std::ctype_base::alpha, L'Ж')) return 2;
    std::mbstate_t state{}; wchar_t wc{};
    if (std::mbrtowc(&wc, "\xd0\x96", 2, &state) != 2 || wc != L'Ж') return 3;
    char bytes[MB_LEN_MAX]; state = {};
    if (std::wcrtomb(bytes, wc, &state) != 2 || std::string(bytes,2) != "\xd0\x96") return 4;
    try { throw std::runtime_error("static/shared unwind"); }
    catch (const std::runtime_error &e) { if (std::string(e.what()) != "static/shared unwind") return 6; }
    int value=0; std::thread t([&]{value=42;}); t.join();
    if (value != 42) return 5;
#ifndef STATIC_PROBE
    target_maps(1, 1);
#endif
}
