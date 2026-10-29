package main
import (
    "testing"
    "tvp.example/helper"
)
func TestAnswer(t *testing.T) { if helper.Answer() != 42 { t.Fatal("wrong answer") } }
