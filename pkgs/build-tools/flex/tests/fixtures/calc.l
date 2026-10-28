%option noyywrap
%{
#include "calc.h"
#include <stdlib.h>
%}
%%
[0-9]+    { yylval = atoi(yytext); return NUMBER; }
[ \t\r]+  ;
.         { return yytext[0]; }
\n        { return '\n'; }
%%
