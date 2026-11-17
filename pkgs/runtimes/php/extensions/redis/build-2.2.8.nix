# Redis 2.2.8 needs PHP 5.2's callable signature and local argument metadata.
args@{
  tvp,
  lib,
  base,
  src,
  version,
  php,
  extensionName,
  phpCompatibility,
  autoconf,
  automake,
  libtool,
  configureOptions ? [ ],
  libraries ? [ ],
  loader ? "extension",
  extensionMeta ? { },
  sourceMode ? "archive",
  compression ? "gzip",
}:
final:
let
  procedure = import ../build-phpize.nix args final;
  context = tvp.builder.forBase final.base;
  php52 =
    final.version == "2.2.8"
    && builtins.compareVersions final.php.version "5.2" >= 0
    && builtins.compareVersions final.php.version "5.3" < 0;
in
procedure
// {
  plan =
    if php52 then
      context.steps.insertAfter "source.unpack" [
        {
          name = "php-redis.php52-sdk";
          cwd = "source";
          tools = [ context.tools.python ];
          run = ''
            ${context.tools.python}/bin/python3 -B - <<'REPAIR'
            import os
            from pathlib import Path
            changes = []
            path = Path('redis_array_impl.c')
            info = path.stat()
            data = path.read_bytes()
            # PHP 5.2 takes check_flags second; PHP 5.3 adds object_ptr there.
            for callback in (b'ra->z_fun', b'ra->z_dist'):
                old = b'zend_is_callable_ex(' + callback + b', NULL, 0, NULL, NULL, NULL, NULL TSRMLS_CC)'
                new = b'zend_is_callable_ex(' + callback + b', 0, NULL, NULL, NULL, NULL, NULL TSRMLS_CC)'
                if data.count(old) != 1:
                    raise ValueError('expected one PHP 5.3 callable check for ' + callback.decode())
                data = data.replace(old, new)
            changes.append((path, info, data))
            path = Path('redis_cluster.c')
            info = path.stat()
            data = path.read_bytes()
            # PHP 5.2's macro lacks the static storage added by PHP 5.3.
            # These arrays otherwise collide with redis.c's distinct metadata.
            for name in (b'arginfo_scan', b'arginfo_kscan'):
                old = b'\nZEND_BEGIN_ARG_INFO_EX(' + name + b', 0, 0, 2)'
                if data.count(old) != 1:
                    raise ValueError('expected one cluster argument-info declaration for ' + name.decode())
                data = data.replace(old, b'\nstatic ' + old[1:])
            changes.append((path, info, data))
            # Validate both files completely before changing either one.
            for path, info, data in changes:
                path.write_bytes(data)
                os.utime(path, ns=(info.st_atime_ns, info.st_mtime_ns))
            REPAIR
          '';
        }
      ] procedure.plan
    else
      procedure.plan;
}
