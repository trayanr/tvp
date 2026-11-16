# Fast build-tool capability gate: no dependency on the Node compiler output.
{ context, python }:
context.mkTest {
  package = python;
  name = "node-build-python";
  script = ''
    ${python}/bin/python3 -I -B - <<'PYTHON'
    import ctypes
    import ctypes.util
    callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int)(lambda value: value + 1)
    assert callback(41) == 42
    print('ctypes-ok')
    PYTHON
  '';
  expected = "ctypes-ok";
}
