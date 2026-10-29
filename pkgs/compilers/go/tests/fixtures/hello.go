package main
import (
    "fmt"
    "encoding/json"
    "math/big"
)
func main() {
    n := new(big.Int).Exp(big.NewInt(2), big.NewInt(128), nil)
    if n.String() != "340282366920938463463374607431768211456" { panic("arithmetic") }
    b, err := json.Marshal(map[string]int{"answer":42})
    if err != nil { panic(err) }
    fmt.Println(string(b))
}
