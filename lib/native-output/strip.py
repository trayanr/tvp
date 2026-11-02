from common import elf, files, invocation, tool

root, config = invocation()
for path in files(root, config["paths"]):
    if elf(path, config["readelf"]) is not None:
        tool(config["strip"], *config["flags"], "--", path)
