{ package }:
let
  deps = package.tvp.deps;
in
package.testContext.mkSuite {
  inherit package;
  tools = package.specification.environment.tools ++ [ deps.binutils ];
  libraries = [
    package
    deps.zlib
    deps.libgcc
  ];
  tests = {
    installed-encoding = {
      script = ''
        cat > encoding.tcl <<'TCL'
        if {[catch {
          if {[info library] ne "${package}/lib/tcl8.6"} {error wrong-library-path}
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
        cc ${./fixtures/native-cancel.c} -ltcl8.6 -pthread -o cancel
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
          if {[package require sqlite3] ne "3.53.0"} {error sqlite-version}
          sqlite3 db :memory:
          db eval {create table t(n); insert into t values(40),(2)}
          if {[db onecolumn {select sum(n) from t}] != 42} {error sqlite-query}
          db backup fixture.db
          db close
          if {[package require tdbc::sqlite3] ne "1.1.13"} {error tdbc-sqlite-version}
          tdbc::sqlite3::connection create conn :memory:
          set statement [conn prepare {select 40+2 as answer}]
          set result [$statement execute]
          if {![$result nextdict row] || [dict get $row answer] != 42} {error tdbc-sqlite-query}
          $result close
          $statement close
          conn close
          if {[package require Itcl] ne "4.3.7"} {error itcl-version}
          itcl::class Counter { public variable n 40; method add {} {incr n 2} }
          Counter c
          if {[c add] != 42} {error itcl-method}
          if {[package require tdbc] ne "1.1.13"} {error tdbc-version}
          if {[tdbc::tokenize {select :answer}] ne {{select } :answer}} {error tdbc-tokenize}
          if {[package require Thread] ne "2.8.13"} {error thread-version}
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
        test -f ${package}/lib/libtclstub8.6.a
        test -f ${package}/include/tclInt.h
        cat > answer.c <<'C'
        #define USE_TCL_STUBS
        #include <tcl.h>
        static int answer(ClientData c,Tcl_Interp *i,int n,Tcl_Obj *const v[]) {
          Tcl_SetObjResult(i,Tcl_NewIntObj(42)); return TCL_OK;
        }
        int Answer_Init(Tcl_Interp *i) {
          if(!Tcl_InitStubs(i,"8.6",0)) return TCL_ERROR;
          Tcl_CreateObjCommand(i,"answer",answer,0,0);
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
