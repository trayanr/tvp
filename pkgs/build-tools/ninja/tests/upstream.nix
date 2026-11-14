# Existing upstream scope: the complete misc/ninja_syntax_test.py group only.
# C++ ninja_test still requires external GoogleTest; no expanded coverage claimed.
{ package, context }: context.mkUpstream { inherit package; }
