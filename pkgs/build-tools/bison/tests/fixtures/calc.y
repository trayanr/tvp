%{
#include <stdio.h>
int yylex(void);
void yyerror(const char *message);
%}
%token NUMBER
%%
input: NUMBER '+' NUMBER { printf("%d\n", $1 + $3); };
%%
int yylex(void) {
    static int token;
    switch (token++) {
        case 0: yylval = 20; return NUMBER;
        case 1: return '+';
        case 2: yylval = 22; return NUMBER;
        default: return 0;
    }
}
void yyerror(const char *message) { fprintf(stderr, "%s\n", message); }
int main(void) { return yyparse(); }
