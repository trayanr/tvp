{
  pkgs,
  tvpLib,
  package,
  unzip,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''zip -v | awk '/This is Zip/ {print $4}' '';
      expected = "3.0";
    };
    roundtrip = {
      script = ''
        mkdir input output
        printf preserved > input/hello.txt
        dd if=/dev/zero of=input/large bs=1024 count=128 2>/dev/null
        zip -q -r archive.zip input
        unzip -t archive.zip > integrity
        unzip -q archive.zip -d output
        cmp input/hello.txt output/input/hello.txt
        cmp input/large output/input/large
        cat output/input/hello.txt
      '';
      expected = "preserved";
      extraInputs = [ unzip ];
    };
  };
}
