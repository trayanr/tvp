{
  pkgs,
  tvpLib,
  tvp,
  package,
}:
package.testContext.mkSuite {
  inherit package;
  tools = with package.specification; [
    gawk
    gnugrep
  ];
  tests = {
    rust-link = {
      script = ''
        printf '%s\n' 'int answer(void) { return 42; }' > answer.c
        "$CC" -c answer.c -o answer.o
        "$AR" crs libanswer.a answer.o
        printf '%s\n' 'unsafe extern "C" { fn answer() -> i32; }' 'fn main() { assert_eq!(unsafe { answer() }, 42); println!("rust-native-ok"); }' > probe.rs
        rustc --edition=2024 -C linker="$CC" -L native=. -l static=answer probe.rs -o probe
        cargo --version > cargo-version.log
        ${package.tvp.deps.binutils}/bin/readelf -l probe > elf.log
        ${package.specification.helperPython}/bin/python3 -c "from pathlib import Path; assert '${package.compiler.libc}/lib/ld-linux-x86-64.so.2' in Path('elf.log').read_text()"
        ./probe
      '';
      tools = [
        package.tvp.deps.rustc
        package.tvp.deps.cargo
        package.tvp.deps.binutils
        package.specification.helperPython
      ];
      expected = "rust-native-ok";
    };
    interface = {
      script = ''
        test "$(git --exec-path)" = ${package}/libexec/git-core
        test -x ${package}/libexec/git-core/git-remote-http
        test -x ${package}/libexec/git-core/git-http-backend
        test -f ${package}/share/git-core/templates/hooks/pre-commit.sample
        test ${package}/bin/git -ef ${package}/libexec/git-core/git-add
        ${package.specification.helperPython}/bin/python3 -c "from pathlib import Path; p=Path('${package}/libexec/git-core'); assert (p/'git-submodule').read_text().startswith('#!${package.specification.runtime.shell}/bin/bash'); assert (p/'git-send-email').read_text().startswith('#!${package.specification.runtime.perl}/bin/perl')"
        printf interfaces-ok
      '';
      tools = [ package.specification.helperPython ];
      expected = "interfaces-ok";
    };
    version = {
      script = ''git --version | awk '{print $3}' '';
      expected = package.version;
    };
    repository = {
      script = ''
        export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
        git init -q repo
        cd repo
        git config user.name TVP
        git config user.email tvp@example.invalid
        printf tvp42 > answer.txt
        git add answer.txt
        git commit -qm preserved
        git grep -P -q '(?<=tvp)42'
        git fsck --full --strict > integrity.log
        git clone --quiet --no-local "$PWD" ../clone
        test "$(cat ../clone/answer.txt)" = tvp42
        git -C ../clone log -1 --format=%s
      '';
      expected = "preserved";
    };
    http = {
      script = ''
        export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
        git init -q repo
        git -C repo config user.name TVP
        git -C repo config user.email tvp@example.invalid
        printf 42 > repo/answer.txt
        git -C repo add answer.txt
        git -C repo commit -qm preserved
        mkdir www
        git clone --bare --quiet repo www/remote.git
        git --git-dir=www/remote.git update-server-info
        python3 ${./fixtures/server.py} "$PWD/www" "$PWD/port" > server.log 2>&1 &
        server=$!
        trap 'kill "$server"; wait "$server" || true' EXIT
        for attempt in $(seq 1 100); do if test -s port; then break; fi; sleep 0.05; done
        port=$(cat port)
        git clone --quiet "http://127.0.0.1:$port/remote.git" clone
        cat clone/answer.txt
      '';
      expected = "42";
      tools = [ package.tvp.deps.python ];
    };
  };
}
