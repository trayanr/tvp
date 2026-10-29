{
  pkgs,
  tvpLib,
  package,
  zip,
}:
tvpLib.tests.mkSuite {
  inherit pkgs package;
  tests = {
    version = {
      script = ''unzip -v | awk 'NR==1 {print $2}' '';
      expected = "6.00";
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
      extraInputs = [ zip ];
    };
  };
}
