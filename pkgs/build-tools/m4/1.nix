{ defs }:
[
  {
    def = defs."1.4.17";
    status = {
      level = "broken";
      reason = "The bundled gnulib tests SIGSTKSZ in a preprocessor conditional (lib/c-stack.c), and glibc 2.34 redefined it from a constant to a sysconf() call, so the file no longer preprocesses.";
      needs = "A period glibc (< 2.34). The code was correct when released; the substrate moved under it. Upstream's own fix was a full gnulib rewrite that arrived in 1.4.19, not a change TVP can apply backwards.";
    };
    releases = {
      "1.4.17" = "sha256-POclEz7lUri0usp4N/t3KUCyXoGyqdySU3rq9zNTjJ4=";
      "1.4.18" = "sha256-qyYzkhpc045IeXv1UhrSWb3EuXkHgDSjt5DX/sVJP6s=";
    };
  }

  {
    def = defs."1.4.17";
    releases = {
      "1.4.19" = "sha256-O+SibYJf/f2lKlb8QyRkVpiaNjAJPM7T+930dx7linA=";
      "1.4.20" = "sha256-asT8Mc5EDevmOYfC67+de2Y05np8Mnklfcc2Hei9s+8=";
      "1.4.21" = "sha256-OK5Z96ML+cEIGTzFwl+7BgFPIeIwx+3i7/YU97fDftg=";
    };
  }
]
