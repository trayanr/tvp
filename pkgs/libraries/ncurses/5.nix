{ defs }:
[
  {
    def = defs."5.0";
    status = {
      level = "degraded";
      capability = "cxx";
      reason = "The C++ binding is not built; libncurses++ and its headers are absent.";
      needs = "A C++ library shipping <strstream.h>, which no compiler since gcc 2.95 provides. 5.3 stopped requiring it.";
      blocked = {
        base = "gcc<=2.95";
      };
    };
    releases = {
      "5.0" = "sha256-pYu8/SpP2CsmCc89cA0ZM99hQNrUW0r4P9xdI6YcKd8=";
      "5.1" = "sha256-2FXO0nG47MBUzx16XZeTqDlEMFvQBpsqfsvtZu4DGYA=";
      "5.2" = "sha256-fRh7v3B7Yn7q6hC/EbctXngdespZEOFgLG9jI7ckq4Q=";
    };
  }
  {
    def = defs."4.2";
    releases = {
      "5.3" = "sha256-bKyXPdMfnnpQXkX/qbuCz6a0H4S0gy/XdeFYV+6bNdQ=";
      "5.4" = "sha256-WrzgY89DF5D05qgBqWx+6gszpB7NCXD2MS9SV1wIOzY=";
      "5.5" = "sha256-J6Y/OirJ0Twe2aCjPuRJfBmmtYELj5c452VKDhIiW5M=";
      "5.6" = "sha256-+crCsxaDo31lvDcRlZl1IZigaR5GLQ0aJSz5gV9XJNU=";
      "5.7" = "sha256-Cpvepcfeje1ckyftZCkV8sw4B1PxLUrRIO99o+o0mPQ=";
    };
  }
  {
    def = defs."5.8";
    releases = {
      "5.8" = "sha256-UVl/if1TqpkDIZVOM+W0hpxKXuYTe/qAD5j5HUtrVLU=";
      "5.9" = "sha256-kEYpj7RAMkydQTXs6nh5/+2FRt0bWOWUMOoHpGM/Vjs=";
    };
  }
]
