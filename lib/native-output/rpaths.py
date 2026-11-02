from common import elf, files, invocation, preserving_times, store_directories, tool

root, config = invocation()
preserve = store_directories(config["dlopenDirectories"])
for path in files(root, config["paths"]):
    classification = elf(path, config["readelf"])
    if classification is None or not classification[0]:
        continue

    def shrink():
        # Unexpected dynamic-ELF/tool errors fail, unlike static ELF above.
        tool(config["patchelf"], "--print-rpath", path)
        tool(config["patchelf"], "--shrink-rpath", path)
        after = tool(config["patchelf"], "--print-rpath", path).rstrip("\n")
        paths = after.split(":") if after else []
        for directory in preserve:
            if directory not in paths:
                paths.append(directory)
        retained = ":".join(paths)
        if retained != after:
            tool(config["patchelf"], "--set-rpath", retained, path)

    preserving_times(path, shrink)
