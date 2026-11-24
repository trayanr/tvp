# Each gem owns its named inputs, build defaults and installed checks together.
{
  lib,
  pkgs,
  helpers,
}:
let
  call = path: import path { inherit lib pkgs helpers; };
in
{
  pg = call ./pg;
  ffi = call ./ffi;
  ethon = call ./ethon;
  rbtrace = call ./rbtrace;
  activerecord = call ./activerecord;
  rmagick = call ./rmagick;
  nokogiri = call ./nokogiri;
}
