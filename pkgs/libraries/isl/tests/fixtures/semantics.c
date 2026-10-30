#include <isl/aff.h>
#include <isl/ast_type.h>
#include <isl/map.h>
#include <isl/set.h>
#include <isl/val.h>
#include <stdio.h>
#include <stdlib.h>

#define REQUIRE(x) do { if (!(x)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #x); exit(1); } } while (0)

static void set_equal(isl_set *actual, isl_set *expected) {
    REQUIRE(actual && expected);
    REQUIRE(isl_set_is_equal(actual, expected) == isl_bool_true);
    isl_set_free(actual); isl_set_free(expected);
}
static void map_equal(isl_map *actual, isl_map *expected) {
    REQUIRE(actual && expected);
    REQUIRE(isl_map_is_equal(actual, expected) == isl_bool_true);
    isl_map_free(actual); isl_map_free(expected);
}
int main(void) {
    isl_ctx *ctx = isl_ctx_alloc();
    REQUIRE(ctx);
    /* Deliberately guard the 0.21 API boundary rather than aliasing old types. */
#ifdef MODERN_API
    isl_size dimensions;
    enum isl_ast_expr_op_type op = isl_ast_expr_op_add;
    REQUIRE(op == isl_ast_expr_op_add);
#else
    int dimensions;
    enum isl_ast_op_type op = isl_ast_op_add;
    REQUIRE(op == isl_ast_op_add);
#endif
    isl_set *triangle = isl_set_read_from_str(ctx, "{ [i,j] : 0 <= i < 5 and 0 <= j <= i }");
    REQUIRE(triangle);
    dimensions = isl_set_dim(triangle, isl_dim_set);
    REQUIRE(dimensions == 2);
    isl_val *count = isl_set_count_val(triangle);
    REQUIRE(count && isl_val_is_int(count) == isl_bool_true && isl_val_get_num_si(count) == 15);
    isl_val_free(count);
    set_equal(isl_set_project_out(triangle, isl_dim_set, 1, 1),
              isl_set_read_from_str(ctx, "{ [i] : 0 <= i <= 4 }"));
    puts("PASS bounded integer set counting and existential projection");

    isl_map *f = isl_map_read_from_str(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = 2*i+1 }");
    REQUIRE(f);
    set_equal(isl_set_apply(isl_set_read_from_str(ctx, "{ [i] : 0 <= i <= 4 and i % 2 = 0 }"), isl_map_copy(f)),
              isl_set_read_from_str(ctx, "{ [j] : j = 1 or j = 5 or j = 9 }"));
    map_equal(isl_map_apply_range(isl_map_copy(f), isl_map_reverse(isl_map_copy(f))),
              isl_map_read_from_str(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = i }"));
    isl_map_free(f);
    puts("PASS map image, modular domain and inverse composition");

    map_equal(isl_map_from_pw_aff(isl_pw_aff_read_from_str(ctx, "{ [i] -> [(3*i+2)] : 0 <= i <= 4 }")),
              isl_map_read_from_str(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = 3*i+2 }"));
    puts("PASS piecewise affine expression semantic equality");
    isl_map *choices = isl_map_read_from_str(ctx, "{ [i] -> [j] : 0 <= i <= 4 and i <= j <= i+3 }");
    REQUIRE(choices);
    map_equal(isl_map_lexmin(isl_map_copy(choices)),
              isl_map_read_from_str(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = i }"));
    map_equal(isl_map_lexmax(choices),
              isl_map_read_from_str(ctx, "{ [i] -> [j] : 0 <= i <= 4 and j = i+3 }"));
    puts("PASS bounded lexicographic minimum and maximum");
    set_equal(isl_set_coalesce(isl_set_read_from_str(ctx, "{ [i] : 0 <= i <= 3; [i] : 2 <= i <= 6 }")),
              isl_set_read_from_str(ctx, "{ [i] : 0 <= i <= 6 }"));
    puts("PASS coalescing preserves union semantics");

    isl_pw_aff *empty = isl_pw_aff_read_from_str(ctx, "{ [i] -> [(0)] : false }");
    isl_pw_aff *piece = isl_pw_aff_read_from_str(ctx, "{ [i] -> [(i+1)] : 0 <= i <= 4 }");
    REQUIRE(empty && piece);
    isl_pw_aff *sum = isl_pw_aff_add(isl_pw_aff_copy(empty), isl_pw_aff_copy(piece));
    REQUIRE(sum && isl_pw_aff_is_equal(sum, empty) == isl_bool_true);
    isl_pw_aff_free(sum);
    /* union_add treats an empty domain as an additive identity; add intersects. */
    sum = isl_pw_aff_union_add(empty, isl_pw_aff_copy(piece));
    REQUIRE(sum && isl_pw_aff_is_equal(sum, piece) == isl_bool_true);
    isl_pw_aff_free(sum); isl_pw_aff_free(piece);
    puts("PASS empty piecewise add and union_add controls");
    isl_ctx_free(ctx);
    return 0;
}
