#!@shell@
# Both variables are mandatory in the core; override ambient caller bindings.
export TVP_NINJA_SHELL='@shell@'
export TVP_NINJA_PYTHON='@python@'
exec '@out@/libexec/ninja' "$@"
