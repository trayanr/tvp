%option noyywrap reentrant
%{
#include <stdlib.h>
%}
%%
[0-9]+ { return atoi(yytext); }
[ \t\r\n]+ ;
. { return -1; }
%%
