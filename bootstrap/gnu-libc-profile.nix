# Opt-in libc capabilities; no compiler, environment or public base replacement.
{
  bootstrap ? import ./. { },
}:
{
  libc = bootstrap.gnu-libc-capabilities;
}
