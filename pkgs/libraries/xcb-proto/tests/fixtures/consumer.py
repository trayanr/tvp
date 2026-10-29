import sys
from collections import defaultdict
output = defaultdict(lambda: lambda *args, **kwargs: None)
from xcbgen.state import Module
module = Module(sys.argv[1], output)
module.register()
module.resolve()
assert module.namespace.header == "xproto"
assert len(module.types) > 100
print("xcbgen-ok")
