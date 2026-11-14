{ package }:
{
  tools = [ package.specification.toolPython ];
  script = ''
    ${package.specification.toolPython}/bin/python3 -B ${./relocate-phar.py} ${../relocate.py} >&2
    phar help > phar-help
    test -s phar-help
    php -r '$p = new Phar($argv[1]); if (!$p->getSignature()) exit(1); echo "phar-ok";' \
      ${package}/bin/phar.phar
  '';
  expected = "phar-ok";
}
