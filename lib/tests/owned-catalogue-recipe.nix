# Evaluation fixture for the explicit catalogue constructor protocol.
{
  base,
  src,
  version,
  bash,
  coreutils,
  dependency,
  patches ? [ ],
  enabled ? true,
}:
{
  pname = "owned-catalogue-fixture";
  inherit
    base
    src
    version
    bash
    coreutils
    ;
  plan = [
    {
      name = "fixture.active";
      run = ":";
    }
    {
      name = "fixture.disabled";
      inherit enabled;
      libraries = [ dependency ];
      run = ":";
    }
  ];
}
