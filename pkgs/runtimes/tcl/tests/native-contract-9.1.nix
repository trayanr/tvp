{ package }:
let
  deps = package.tvp.deps // {
    inherit (package.runtime) zlib libgcc;
  };
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ package.specification.tools.binutils ];
  libraries = [
    package
    deps.zlib
    deps.libgcc
  ];
  tests = {
    source-controls =
      let
        source = package.edit (s: s // { src = builtins.toFile "tcl-source-probe" "probe"; });
        base = package.edit (s: s // { base = s.base.override { name = "tcl-base-probe"; }; });
        environment = package.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.TCL_SOURCE_PROBE = "effective";
            };
          }
        );
        off = package.override { doCheck = false; };
        inspector = (import ../../../../bases/source-gnu/tests/probes.nix { }).sentinel;
        editedInspector = package.edit (
          s:
          s
          // {
            tools = s.tools // {
              binutils = inspector;
            };
          }
        );
        # The compiler's independent bintools may remain later in the path.
        firstInspector =
          name:
          builtins.head (
            builtins.filter (
              tool:
              builtins.elem (toString tool) [
                (toString inspector)
                (toString package.specification.tools.binutils)
              ]
            ) (builtins.head editedInspector.tests.${name}.buildSteps).tools
          );
      in
      {
        script =
          assert !(builtins.tryEval (package.editRuntime (r: r // { libraries = [ ]; })).drvPath).success;
          assert source.drvPath != package.drvPath;
          assert source.tests.version.package.outPath == source.outPath;
          assert toString (firstInspector "version") == toString inspector;
          assert toString (firstInspector "stub-extension") == toString inspector;
          assert base.tvp.base == "tcl-base-probe";
          assert base.tests.version.specification.base.name == "tcl-base-probe";
          assert builtins.any (s: (s.env.TCL_SOURCE_PROBE or "") == "effective") environment.buildSteps;
          assert off.artifact.drvPath == package.artifact.drvPath;
          assert off.drvPath == package.drvPath;
          assert !(off.tests ? upstream);
          "printf source-controls-ok";
        expected = "source-controls-ok";
      };

    zipfs-command = {
      script = ''
        cat > zipfs.tcl <<'TCL'
        if {[catch {
          if {[string match {//zipfs:*} [info library]]} {error unexpected-script-image}
          file mkdir payload
          set f [open payload/answer.txt w]; puts -nonewline $f 42; close $f
          zipfs mkzip fixture.zip payload
          zipfs mount fixture.zip tvp
          set entries [zipfs list -glob *answer.txt]
          if {[llength $entries] != 1} {error zipfs-entry}
          set f [open [lindex $entries 0]]; set answer [read $f]; close $f
          if {$answer ne "42"} {error zipfs-content}
          zipfs unmount tvp
        } why]} {puts stderr $why; exit 1}
        puts zipfs-command-ok
        TCL
        tclsh zipfs.tcl
      '';
      expected = "zipfs-command-ok";
    };
    installed-encoding = {
      script = ''
        cat > encoding.tcl <<'TCL'
        if {[catch {
          if {[info library] ne "${package}/lib/tcl9.1"} {error wrong-library-path}
          if {![file exists [file join [info library] encoding cp1251.enc]]} {error missing-encoding-table}
          set bytes [binary format H* cff0e8e2e5f2]
          set text [encoding convertfrom cp1251 $bytes]
          if {$text ne "\u041f\u0440\u0438\u0432\u0435\u0442"} {error encoding-decode}
          if {[encoding convertto cp1251 $text] ne $bytes} {error encoding-roundtrip}
        } why]} {puts stderr $why; exit 1}
        puts encoding-ok
        TCL
        tclsh encoding.tcl
      '';
      expected = "encoding-ok";
    };

    thread-cancellation = {
      script = ''
        cc ${./fixtures/native-cancel.c} -ltcl9.1 -pthread -o cancel
        LD_DEBUG=libs timeout 20 ./cancel 2>loaded
        grep -F 'calling init: ${deps.libgcc}/lib/libgcc_s.so.1' loaded >/dev/null
        printf cancellation-ok
      '';
      expected = "cancellation-ok";
    };

    external-driver-boundaries = {
      script = ''
        cat > drivers.tcl <<'TCL'
        if {[catch {
          foreach {driver client} {mysql libmysql.so odbc libiodbc.so postgres libpq.so} {
            # No external client library is declared by the ordinary profile.
            # Prove that each installed loader reaches that specific boundary.
            set rc [catch {package require tdbc::$driver} message]
            if {!$rc || ![string match "*couldn't load file*$client*" $message]} {
              error "unexpected $driver client-library boundary: $rc $message"
            }
          }
        } why opts]} {puts stderr "$why\n[dict get $opts -errorinfo]"; exit 1}
        puts external-client-libraries-unavailable
        TCL
        tclsh drivers.tcl
      '';
      expected = "external-client-libraries-unavailable";
    };

    bundled-packages = {
      script = ''
        cat > packages.tcl <<'TCL'
        if {[catch {
          if {[package require sqlite3] ne "3.53.4"} {error sqlite-version}
          sqlite3 db :memory:
          db eval {create table t(n); insert into t values(40),(2)}
          if {[db onecolumn {select sum(n) from t}] != 42} {error sqlite-query}
          db backup fixture.db
          db close
          if {[package require tdbc::sqlite3] ne "1.1.15"} {error tdbc-sqlite-version}
          tdbc::sqlite3::connection create conn :memory:
          set statement [conn prepare {select 40+2 as answer}]
          set result [$statement execute]
          if {![$result nextdict row] || [dict get $row answer] != 42} {error tdbc-sqlite-query}
          $result close
          $statement close
          conn close
          if {[package require Itcl] ne "4.3.8"} {error itcl-version}
          itcl::class Counter { public variable n 40; method add {} {incr n 2} }
          Counter c
          if {[c add] != 42} {error itcl-method}
          if {[package require tdbc] ne "1.1.15"} {error tdbc-version}
          if {[tdbc::tokenize {select :answer}] ne {{select } :answer}} {error tdbc-tokenize}
          if {[package require Thread] ne "3.0.7"} {error thread-version}
          set tid [thread::create -joinable {thread::wait}]
          if {[thread::send $tid {expr {40+2}}] != 42} {error thread-result}
          thread::release $tid
          thread::join $tid
        } why opts]} {puts stderr "$why\n[dict get $opts -errorinfo]"; exit 1}
        puts packages-ok
        TCL
        tclsh packages.tcl
        sqlite3_analyzer fixture.db > analyzer.txt
        grep -F 'Page size in bytes' analyzer.txt >/dev/null
      '';
      expected = "packages-ok";
    };
    stub-extension = {
      script = ''
        . ${package}/lib/tclConfig.sh
        test -f ${package}/lib/libtclstub.a
        test -f ${package}/include/tclInt.h
        cat > answer.c <<'C'
        #define USE_TCL_STUBS
        #include <tcl.h>
        static int answer(ClientData c,Tcl_Interp *i,Tcl_Size n,Tcl_Obj *const v[]) {
          Tcl_SetObjResult(i,Tcl_NewIntObj(42)); return TCL_OK;
        }
        int Answer_Init(Tcl_Interp *i) {
          if(!Tcl_InitStubs(i,"9.1",0)) return TCL_ERROR;
          Tcl_CreateObjCommand2(i,"answer",answer,0,0);
          return Tcl_PkgProvide(i,"answer","1.0");
        }
        C
        cc -fPIC -shared $TCL_INCLUDE_SPEC answer.c $TCL_STUB_LIB_SPEC -o answer.so
        readelf -d answer.so > dynamic
        if grep 'NEEDED.*libtcl' dynamic; then exit 1; fi
        cat > extension.tcl <<'TCL'
        if {[catch {
          load ./answer.so
          if {[answer] != 42 || [package require answer] ne "1.0"} {error extension-result}
        } why]} {puts stderr $why; exit 1}
        puts extension-ok
        TCL
        tclsh extension.tcl
      '';
      expected = "extension-ok";
    };
  };
}
