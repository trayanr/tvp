{
  pkgs,
  tvpLib,
  package,
  python,
  jdk,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''${package}/bin/msgfmt --version | head -1 | awk '{print $NF}' '';
      expected = package.version;
    };
    catalog = {
      extraInputs = [
        python
        package.tvp.cc
        package.stdenv.cc.libc.bin
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
        tar -xf ${package.stdenv.cc.libc.src} glibc-${package.stdenv.cc.libc.version}/localedata || exit 1
        mkdir locale
        I18NPATH="$PWD/glibc-${package.stdenv.cc.libc.version}/localedata" \
          localedef --no-archive -i fr_FR -f UTF-8 "$PWD/locale/fr_FR.UTF-8" || exit 1
        cc ${./catalog.c} -o catalog || exit 1
        LOCPATH="$PWD/locale" ./catalog "$PWD/catalogs" || exit 1
      '';
      expected = "ok";
    };
    format-rejection = {
      script = ''
        printf '#, c-format\nmsgid "value %%s"\nmsgstr "valeur %%d"\n' > bad.po
        if msgfmt --check-format bad.po -o bad.mo 2>error; then exit 1; fi
        grep -E 'format|argument' error >&2 || exit 1
        echo ok
      '';
      expected = "ok";
    };
    extraction-merge = {
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
      extraInputs = [
        python
        package.tvp.cc
      ];
      script = ''
        readelf -h ${package}/bin/spit | grep -F ELF >&2 || exit 1
        LD_TRACE_LOADED_OBJECTS=1 ${package}/bin/spit > loader || exit 1
        grep -F '${package.tvp.deps.json-c}/lib/libjson-c.so' loader >&2 || exit 1
        grep -F '${package.tvp.deps.curl}/lib/libcurl.so' loader >&2 || exit 1
        LC_ALL=C python3 ${./spit.py} ${package}/bin/spit || exit 1
      '';
      expected = "ok";
    };
    shell-helpers = {
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
        echo ok
      '';
      expected = "ok";
    };
    xml = {
      extraInputs = [ python ];
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
      extraInputs = [ jdk ];
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
      extraInputs = [
        package.tvp.cc
      ];
      script = ''
        cc ${./style.c} -ltextstyle -o style || exit 1
        ./style ${package.tvp.deps.ncurses}/share/terminfo || exit 1
        cc ${./po.c} -lgettextpo -o po || exit 1
        ./po || exit 1
        msgfmt --help | grep -F -- '--xml' >&2 || exit 1
      '';
      expected = "ok";
    };
  };
}
