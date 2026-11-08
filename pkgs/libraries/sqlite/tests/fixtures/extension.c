#include <sqlite3ext.h>
SQLITE_EXTENSION_INIT1
static void tvp(sqlite3_context *ctx,int n,sqlite3_value **v) {
  (void)n; (void)v; sqlite3_result_text(ctx,"extension works",-1,SQLITE_STATIC);
}
int sqlite3_extension_init(sqlite3 *db,char **err,const sqlite3_api_routines *api) {
  SQLITE_EXTENSION_INIT2(api);
  return sqlite3_create_function(db,"tvp_extension",0,SQLITE_UTF8,0,tvp,0,0);
}
