# Native GNU/Linux execution facts. Additional architectures need real providers.
{
  system = "x86_64-linux";
  config = "x86_64-unknown-linux-gnu";
  isMusl = false;
  goOS = "linux";
  goArch = "amd64";
  dynamicLinker = "lib/ld-linux-x86-64.so.2";
}
