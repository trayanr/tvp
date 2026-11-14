{
  pkgs,
  tvpLib,
  package,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
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
      extraInputs = [ package.tvp.deps.python ];
    };
  };
}
