#!@bash@
# The frontend locates its helpers relative to argv[0]. Keep it in this
# wrapper directory so HTML dispatch uses the bound interpreter as well.
exec -a "$0" @binutils@/bin/gprofng "$@"
