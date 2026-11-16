{
  package,
  lib,
  context,
}:
{
  tools = [ package.specification.base.tools.python ];
  script = ''
    ${package.specification.base.tools.python}/bin/python3 -B ${./relocate-phar.py} ${../relocate.py} >&2
    phar help > phar-help
    test -s phar-help
    php -r '$p = new Phar($argv[1]); if (!$p->getSignature()) exit(1); echo "phar-ok";' \
      ${package}/bin/phar.phar
  '';
  expected = "phar-ok";
}
