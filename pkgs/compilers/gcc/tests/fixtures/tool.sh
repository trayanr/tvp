#!/bin/sh
tool=${0##*/}
printf '%s\n' "$tool" >> "$TVP_TOOL_TEST_LOG"
exec "$TVP_TOOL_REAL/$tool" "$@"
