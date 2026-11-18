"""Stage one bundled extension and its required inputs from the same release."""

import argparse
from pathlib import Path
import re


def regular_file(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"Expected regular PHP source file: {path}")
    return path


def socket_configuration(path):
    text = regular_file(path).read_text()
    patterns = (
        r"^AC_DEFUN\(\[PHP_MYSQL_SOCKET_SEARCH\], \[\n.*?^\]\)\n",
        r"^PHP_ARG_WITH\(\[mysql-sock\],\n.*?^  \[no\]\)\n",
    )
    blocks = []
    for pattern in patterns:
        matches = re.findall(pattern, text, re.MULTILINE | re.DOTALL)
        if len(matches) != 1 or "PHP_NEW_EXTENSION" in matches[0]:
            raise ValueError(f"Unexpected MySQL socket configuration in {path}")
        blocks.append(matches[0])
    return "\n".join(blocks)


def stage(root, module):
    source = root / "source"
    php = root / "php-source"
    config_name = "config9.m4" if module == "mysqlnd" else "config.m4"
    regular_file(source / "ext" / module / config_name)
    if module != "mysqlnd":
        regular_file(source / "ext/mysqlnd/mysqlnd.h")
    if module == "pdo_mysql":
        socket = socket_configuration(source / "ext/mysqli/config.m4")

    source.rename(php)
    (php / "ext" / module).rename(source)
    if module == "mysqlnd":
        (source / config_name).rename(source / "config.m4")
    else:
        extension_headers = source / "ext"
        extension_headers.mkdir()
        (extension_headers / "mysqlnd").symlink_to("../../php-source/ext/mysqlnd")
    if module == "pdo_mysql":
        config = source / "config.m4"
        config.write_text(socket + "\n" + config.read_text())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("module", choices=("mysqlnd", "mysqli", "pdo_mysql"))
    args = parser.parse_args()
    stage(args.root, args.module)
