#!/bin/sh
# Author: Eduard Abdullin <eabdullin@almalinux.org>

t_Log "Running $0 - golang can run"

go help
t_CheckExitStatus $?

t_Log "Running $0 - golang can build a hello world .go"
# creating source code
FILE='/var/tmp/go-test.go'
EXE='/var/tmp/go-test'

cat > $FILE <<EOF
package main

import "fmt"

func main() {
	fmt.Println("hello, al")
}
EOF

# Executing go build
go build -o $EXE $FILE

# run EXE
$EXE |grep -q 'hello, al'
t_CheckExitStatus $?

# remove files
/bin/rm $FILE
/bin/rm $EXE
