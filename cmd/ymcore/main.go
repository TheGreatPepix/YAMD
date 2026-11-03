package main

import (
	"os"

	"ymd/internal/gui"
	"ymd/internal/update"
)

func main() {
	if len(os.Args) == 3 && os.Args[1] == update.ApplyFlag {
		os.Exit(update.Apply(os.Args[2]))
	}
	os.Exit(gui.RunCore(os.Stdin, os.Stdout))
}
