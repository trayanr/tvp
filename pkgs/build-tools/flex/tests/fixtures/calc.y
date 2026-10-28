%{
#include <stdio.h>
int yylex(void);
void yyerror(const char *message);
%}
%token NUMBER
%%
input: NUMBER '+' NUMBER '\n' { printf("%d\n", $1 + $3); };
%%
void yyerror(const char *message) { fprintf(stderr, "%s\n", message); }
int main(void) { return yyparse(); }
