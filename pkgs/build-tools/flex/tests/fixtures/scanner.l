%option noyywrap
%{
#include <stdio.h>
#include <stdlib.h>
static int total;
%}
%%
[0-9]+    { total += atoi(yytext); }
[ \t\r]+  ;
\n        { printf("%d\n", total); total = 0; }
.         { return 1; }
%%
int main(void) {
#ifdef __cplusplus
    yyFlexLexer lexer;
    return lexer.yylex();
#else
    return yylex();
#endif
}
