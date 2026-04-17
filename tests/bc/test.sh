#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1
 
 
rlJournalStart
    rlPhaseStartTest "Test bc is installed"
    rlRun "bc --version" 0 "Verify bc --version exits successfully"
    rlPhaseEnd
 
    rlPhaseStartTest "Testing basic bc functionalities"
    rlRun "test $(echo '5 + 6 * 5 / 10 - 1' | bc) -eq 7" 0 "Verify arithmetic expression evaluates to 7"
    rlPhaseEnd
rlJournalEnd
