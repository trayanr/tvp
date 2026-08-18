{ defs }:
[
  {
    def = defs."2.0";
    status = {
      level = "broken";
      reason = "readline.h includes readline/tilde.h, which 2.0 omits from INSTALLED_HEADERS, so nothing can compile against the installed tree. The library itself builds.";
      needs = "A patch adding tilde.h to INSTALLED_HEADERS. Deferred rather than impossible: 2.0 already needed a period compiler, a named ncurses include path, an undefined incdir supplied and a pre-created include directory, and a fifth independent fix for one release is re-porting rather than packaging.";
    };
    releases = {
      "2.0" = "sha256-PJYYtkajIHTvt1J7WrJoN9VcSp0Xwr66ec7veA5HQ2c=";
    };
  }

  {
    def = defs."2.0";
    status = {
      level = "degraded";
      capability = "shared";
      reason = "Static libraries only. These releases predate support/shobj-conf and link shared objects with a SunOS-era `ld -assert pure-text` invocation that modern binutils rejects; 2.0 and 2.1 carry no install-shared target at all.";
      needs = "A shared-library rule that works against ELF, which upstream first shipped at 4.0, or a period linker that accepts the rule these releases have.";
    };
    releases = {
      "2.1" = "sha256-vZhE8r2ZBBbNjTskCB1tPGd2/nlQYwYU12iJ8iJCv70=";
    };
  }

  {
    def = defs."2.2";
    status = {
      level = "degraded";
      capability = "shared";
      reason = "Static libraries only. This release predates support/shobj-conf and links shared objects with a SunOS-era `ld -assert pure-text` invocation that modern binutils rejects.";
      needs = "A shared-library rule that works against ELF, which upstream first shipped at 4.0, or a period linker that accepts the rule this release has.";
    };
    releases = {
      "2.2" = "sha256-eErtGTfKrHRqpLiGoMorou8tMRlCCv3iS6pWvHDAbZQ=";
    };
  }

  {
    def = defs."2.2.1";
    status = {
      level = "degraded";
      capability = "shared";
      reason = "Static libraries only. These releases predate support/shobj-conf and link shared objects with a SunOS-era `ld -assert pure-text` invocation that modern binutils rejects; 2.0 and 2.1 carry no install-shared target at all.";
      needs = "A shared-library rule that works against ELF, which upstream first shipped at 4.0, or a period linker that accepts the rule these releases have.";
    };
    releases = {
      "2.2.1" = "sha256-GBmwBUI7eOaHZlN4H+WdmyLtElWGe3NtlckeUpp7Gns=";
    };
  }
]
