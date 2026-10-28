#include <isl/ctx.h>
#include <isl/set.h>
#include <isl/val.h>
#include <stdio.h>
int main(void) { isl_ctx *ctx = isl_ctx_alloc(); isl_set *s = isl_set_read_from_str(ctx, "{ [i] : 0 <= i < 10 and i % 2 = 0 }"); if(!s) return 1; isl_val *n = isl_set_count_val(s); if(!n || !isl_val_is_int(n) || isl_val_get_num_si(n) != 5) return 1; puts("5"); isl_val_free(n); isl_set_free(s); isl_ctx_free(ctx); return 0; }
