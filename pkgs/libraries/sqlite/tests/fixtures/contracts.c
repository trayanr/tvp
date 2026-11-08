#define SQLITE_ENABLE_SESSION 1
#define SQLITE_ENABLE_PREUPDATE_HOOK 1
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define OK(x) do {int rc=(x); if(rc!=SQLITE_OK){fprintf(stderr,"line %d rc %d: %s\n",__LINE__,rc,sqlite3_errmsg(db));exit(1);}}while(0)
#define CHECK(x) do {if(!(x)){fprintf(stderr,"line %d contract failed\n",__LINE__);exit(1);}}while(0)
static int changes;
static void pre(void *p,sqlite3 *d,int op,char const *database,char const *table,sqlite3_int64 a,sqlite3_int64 b) {
  (void)p;(void)d;(void)op;(void)database;(void)table;(void)a;(void)b;changes++;
}
static void sql(sqlite3 *db,const char *s) { OK(sqlite3_exec(db,s,0,0,0)); }
static int scalar(sqlite3 *db,const char *s) {sqlite3_stmt *q;OK(sqlite3_prepare_v2(db,s,-1,&q,0));CHECK(sqlite3_step(q)==SQLITE_ROW);int n=sqlite3_column_int(q,0);OK(sqlite3_finalize(q));return n;}
int main(void) {
  sqlite3 *db,*other; sqlite3_stmt *q; sqlite3_session *session;void *data;int size;
  CHECK(!strcmp(sqlite3_libversion(),"3.53.4"));CHECK(sqlite3_threadsafe());
  OK(sqlite3_open("contracts.db",&db));
  sql(db,"create table t(id integer primary key,v text); begin immediate; insert into t values(1,'persisted');");
  OK(sqlite3_open("contracts.db",&other));
  CHECK(sqlite3_exec(other,"begin immediate",0,0,0)==SQLITE_BUSY);
  sql(db,"commit");sql(other,"begin immediate; rollback");OK(sqlite3_close(other));
  OK(sqlite3_prepare_v2(db,"insert into t values(?,?)",-1,&q,0));
  OK(sqlite3_bind_int(q,1,2));OK(sqlite3_bind_text(q,2,"bound",-1,SQLITE_STATIC));
  CHECK(sqlite3_step(q)==SQLITE_DONE);OK(sqlite3_finalize(q));
  CHECK(scalar(db,"select count(*) from t")==2);
  sql(db,"create virtual table f3 using fts3(v); insert into f3 values('token'); create virtual table f4 using fts4(v); insert into f4 values('token'); create virtual table f5 using fts5(v); insert into f5 values('token');");
  CHECK(scalar(db,"select count(*) from f3 where f3 match 'token'")==1);
  CHECK(scalar(db,"select count(*) from f4 where f4 match 'token'")==1);
  CHECK(scalar(db,"select count(*) from f5 where f5 match 'token'")==1);
  sql(db,"create virtual table r using rtree(id,x0,x1,y0,y1); insert into r values(1,0,2,0,2); create virtual table g using geopoly; insert into g(_shape) values('[[0,0],[2,0],[2,2],[0,2],[0,0]]');");
  CHECK(scalar(db,"select count(*) from r where x1>1")==1);
  CHECK(scalar(db,"select geopoly_contains_point(_shape,1,1) from g")==1);
  CHECK(scalar(db,"select json_extract('{\"a\":42}', '$.a') + sqrt(4)")==44);
  CHECK(scalar(db,"select count(*) from sqlite_dbpage")>0);
  CHECK(scalar(db,"select count(*) from dbstat")>0);
  OK(sqlite3session_create(db,"main",&session));OK(sqlite3session_attach(session,"t"));
  sql(db,"insert into t values(3,'session')");OK(sqlite3session_changeset(session,&size,&data));CHECK(size>0);sqlite3_free(data);sqlite3session_delete(session);
  sqlite3_preupdate_hook(db,pre,0);sql(db,"insert into t values(4,'hook')");CHECK(changes==1);sqlite3_preupdate_hook(db,0,0);
  int values[]={11,22,33};OK(sqlite3_prepare_v2(db,"select sum(value) from carray(?)",-1,&q,0));OK(sqlite3_carray_bind(q,1,values,3,SQLITE_CARRAY_INT32,SQLITE_STATIC));CHECK(sqlite3_step(q)==SQLITE_ROW);CHECK(sqlite3_column_int(q,0)==66);OK(sqlite3_finalize(q));
  OK(sqlite3_close(db));OK(sqlite3_open("contracts.db",&db));CHECK(scalar(db,"select count(*) from t")==4);OK(sqlite3_close(db));
  puts("contracts 3.53.4");return 0;
}
