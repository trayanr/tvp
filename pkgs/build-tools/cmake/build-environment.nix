# CMake's environment uses native path lists, unlike semicolon cache arguments.
# Libraries publish development outputs; the compiler's libc is explicit base
# data, since CMake also searches it for standard system libraries such as libm.
{ lib }:
{
  tool,
  libraries,
  base,
  ...
}:
{
  paths.CMAKE_PREFIX_PATH = {
    separator = ":";
    entries = map (p: "${lib.getDev p}") libraries ++ [ "${lib.getDev base.stdenv.cc.libc}" ];
  };
}
