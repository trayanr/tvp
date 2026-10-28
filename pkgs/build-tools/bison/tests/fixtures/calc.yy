%language "c++"
%define api.value.type {int}
%code {
#include <iostream>
int yylex(yy::parser::semantic_type *value);
}
%token NUMBER
%%
input: NUMBER '+' NUMBER { std::cout << $1 + $3 << '\n'; };
%%
int yylex(yy::parser::semantic_type *value) {
    static int token;
    switch (token++) {
        case 0: *value = 20; return yy::parser::token::NUMBER;
        case 1: return '+';
        case 2: *value = 22; return yy::parser::token::NUMBER;
        default: return 0;
    }
}
void yy::parser::error(const std::string &message) { std::cerr << message << '\n'; }
int main() { yy::parser parser; return parser.parse(); }
