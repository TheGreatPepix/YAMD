package main

import (
	"os"

	"ymd/internal/gui"
)

func main() {
	os.Exit(gui.RunCore(os.Stdin, os.Stdout))
}
