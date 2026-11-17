# Public consumer policy; the base's closed construction providers stay intact.
{ base, builder }:
import ./source-gnu/hardening {
  candidate = {
    inherit base builder;
    tools = base.tools;
  };
  policy.defaults = [
    "bindnow"
    "relro"
  ];
}
