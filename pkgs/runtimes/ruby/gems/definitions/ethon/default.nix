{ lib, helpers, ... }:
let
  check = import ../test.nix { inherit lib; };
in
{
  inputs.curl = args: args.tvp.packages.curl_8;
  configure = final: {
    libraries = [ final.curl ];
    # FFI opens libraries dynamically; an ELF RPATH on a pure Ruby gem cannot
    # select the provider. Keep the library path tied to the named Curl input.
    patches = lib.optionals (final.version == "0.16.0") [
      (helpers.writePatch final "ethon-0.16.0-curl.patch" ''
        --- a/lib/ethon/curls/settings.rb
        +++ b/lib/ethon/curls/settings.rb
        @@ -9,2 +9,2 @@
             ffi_lib_flags :now, :global
        -    ffi_lib ['libcurl', 'libcurl.so.4']
        +    ffi_lib ['${final.curl}/lib/libcurl.so.4']
      '')
    ];
  };
  mkTests = package: {
    load = check package {
      name = "curl-library";
      script = ''
        ${package.ruby}/bin/ruby -rethon -e 'abort "Curl did not load" unless Ethon::Curl.version.include?("libcurl/"); print "ethon-loaded"'
      '';
      expected = "ethon-loaded";
    };
  };
}
