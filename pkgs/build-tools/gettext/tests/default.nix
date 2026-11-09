{
  pkgs,
  tvp,
  tvpLib,
  package,
}:
let
  spec = package.specification;
  python = spec.tools.python;
  jdk = spec.runtime.jdk;
  locale = import ../../../../lib/tests/gnu-locale.nix {
    builder = tvp.builder;
    inherit (spec) base bash coreutils;
    tar = spec.tools.gnutar;
    xz = spec.tools.xz;
    libc = spec.base.compiler.libc;
  };
in
package.testContext.mkSuite {
  inherit package;
  tests = {
    version = {
      tools = [ package.specification.tools.gawk ];
      script = ''${package}/bin/msgfmt --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    catalog = {
      tools = [
        python
        package.specification.base.compiler
        locale
      ];
      script = ''
        mkdir -p catalogs/fr_FR/LC_MESSAGES
        msgfmt --check-format ${./messages.po} -o catalogs/fr_FR/LC_MESSAGES/fixture.mo || exit 1
        python3 - catalogs/fr_FR/LC_MESSAGES/fixture.mo <<'PY'
        import gettext,sys
        with open(sys.argv[1], 'rb') as f: g=gettext.GNUTranslations(f)
        assert g.gettext('Hello') == 'Bonjour'
        assert g.gettext('coffee') == 'café'
        assert g.pgettext('menu','Open') == 'Ouvrir'
        assert g.ngettext('apple','apples',1) == 'pomme'
        assert g.ngettext('apple','apples',2) == 'pommes'
        PY
        test $? = 0 || exit 1
        cc ${./catalog.c} -o catalog || exit 1
        LOCPATH=${locale} ./catalog "$PWD/catalogs" || exit 1
      '';
      expected = "ok";
    };
    format-rejection = {
      tools = [ package.specification.tools.grep ];
      script = ''
        printf '#, c-format\nmsgid "value %%s"\nmsgstr "valeur %%d"\n' > bad.po
        if msgfmt --check-format bad.po -o bad.mo 2>error; then exit 1; fi
        grep -E 'format|argument' error >&2 || exit 1
        echo ok
      '';
      expected = "ok";
    };
    extraction-merge = {
      tools = [ package.specification.tools.grep ];
      script = ''
        printf 'void f(void) { gettext("Hello"); gettext("New"); }\n' > source.c
        xgettext --from-code=UTF-8 -L C -o extracted.pot source.c || exit 1
        grep -F 'msgid "New"' extracted.pot >&2 || exit 1
        msgmerge --no-wrap ${./messages.po} extracted.pot -o merged.po >&2 || exit 1
        grep -F 'msgstr "Bonjour"' merged.po >&2 || exit 1
        echo ok
      '';
      expected = "ok";
    };
    native-spit = {
      tools = [
        python
        package.specification.tools.binutils
        package.specification.tools.grep
      ];
      script = ''
        readelf -h ${package}/bin/spit | grep -F ELF >&2 || exit 1
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/spit > loader || exit 1
        grep -F '${package.specification.providers.json-c}/lib/libjson-c.so' loader >&2 || exit 1
        grep -F '${package.specification.providers.curl}/lib/libcurl.so' loader >&2 || exit 1
        LC_ALL=C python3 ${./spit.py} ${package}/bin/spit || exit 1
      '';
      expected = "ok";
    };
    shell-helpers = {
      tools =
        [ spec.tools.grep ]
        ++ (with package.tvp.declaredTestDependencies; [
          autoconf
          automake
          libtool
        ]);
      script = ''
        actual=$(
          PATH=/nonexistent
          . ${package}/bin/gettext.sh || exit 1
          name=TVP; export name
          eval_gettext 'Hello $name' || exit 1
          eval_pgettext menu 'Open $name' || exit 1
          eval_ngettext '$name apple' '$name apples' 2 || exit 1
        ) || exit 1
        test "$actual" = 'Hello TVPOpen TVPTVP apples' || exit 1
        # Caller supplies the Autotools ecosystem; helper core tools are internal.
        mkdir helper-project
        cd helper-project
        printf 'AC_INIT([fixture], [1])\nAC_CONFIG_SRCDIR([hello.c])\nAM_GNU_GETTEXT([external])\nAM_GNU_GETTEXT_VERSION([1.0])\nAC_OUTPUT\n' > configure.ac
        touch hello.c
        ${package}/bin/autopoint --force > autopoint.log 2>&1 || { cat autopoint.log >&2; exit 1; }
        test -s m4/gettext.m4 || exit 1
        test -s po/Makefile.in.in || exit 1
        # gettextize retains its upstream acknowledgement (no TTY in sandbox).
        ${package}/bin/gettextize --force --no-changelog > gettextize.log 2>&1 || { cat gettextize.log >&2; exit 1; }
        test -s m4/gettext.m4 || exit 1
        PATH=/nonexistent ${package}/libexec/gettext/project-id > identity || exit 1
        cp ${./messages.po} messages.pot
        PATH=/nonexistent ${package}/bin/msginit --no-translator -l fr_FR -i messages.pot -o initialized.po > msginit.log 2>&1 || { cat msginit.log >&2; exit 1; }
        grep -F 'Language: fr' initialized.po >&2 || exit 1
        echo ok
      '';
      expected = "ok";
    };
    xml = {
      tools = [ python ];
      script = ''
        printf '<component type="desktop"><id>fixture</id><name>Hello</name></component>\n' > fixture.appdata.xml
        msgfmt --xml --template=fixture.appdata.xml -l fr ${./messages.po} -o translated.xml || exit 1
        python3 - <<'PYXML'
        import xml.etree.ElementTree as E
        root=E.parse('translated.xml').getroot()
        assert any(n.text == 'Bonjour' and n.get('{http://www.w3.org/XML/1998/namespace}lang') == 'fr' for n in root.findall('name'))
        PYXML
        test $? = 0 || exit 1
        echo ok
      '';
      expected = "ok";
    };
    java = {
      tools = [ jdk ];
      script = ''
        mkdir classes
        msgfmt --java -r fixture -l fr -d classes ${./messages.po} || exit 1
        cp ${./Catalog.java} Catalog.java || exit 1
        javac -cp ${package}/share/gettext/libintl.jar -d classes Catalog.java || exit 1
        java -cp classes:${package}/share/gettext/libintl.jar Catalog || exit 1
      '';
      expected = "ok";
    };
    libraries = {
      libraries = [ package ];
      tools = [
        spec.tools.grep
      ];
      script = ''
        test -f ${package}/lib/libtextstyle.a || exit 1
        test -f ${package}/lib/libgettextpo.a || exit 1
        test -s ${package}/share/aclocal/gettext.m4 || exit 1
        cc ${./style.c} -ltextstyle -o style || exit 1
        ./style ${package.specification.providers.ncurses}/share/terminfo || exit 1
        cc ${./po.c} -lgettextpo -o po || exit 1
        ./po || exit 1
        msgfmt --help | grep -F -- '--xml' >&2 || exit 1
      '';
      expected = "ok";
    };
  };
}
