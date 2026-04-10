#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

FILE=$(mktemp)
EXE=$(mktemp)

rlJournalStart

    rlPhaseStartSetup
    cat > "$FILE" <<EOF
#include <iostream>
int main(int argc, char** argv) {
	std::cout << "hello, centos" << std::endl;
}
EOF
    rlPhaseEnd

    rlPhaseStartTest "gcc can build and run a hello world C program"
    rlRun "g++ $FILE -o $EXE" 0 "Compiling hello world with gcc"
    rlAssertExists "$EXE"
    rlRun -s "$EXE" 0 "Executable prints expected output"
    rlAssertGrep "hello, centos" $rlRun_LOG
    rlPhaseEnd

    rlPhaseStartCleanup
    rlRun "rm -f $FILE $EXE" 0 "Removing temporary files"
    rlPhaseEnd
rlJournalEnd
