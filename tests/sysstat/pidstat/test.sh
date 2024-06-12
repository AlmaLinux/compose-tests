#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart

  rlPhaseStartSetup
  rlRun "yum install -y sysstat" 0 "Install sysstat"
  rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory' # no-reboot
  rlRun "pushd $TmpDir"
  rlPhaseEnd

  rlPhaseStartTest
  rlRun "pidstat 1 1"
  rlPhaseEnd

  rlPhaseStartCleanup
  rlRun "popd"
  rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
  rlRun "yum remove -y sysstat" 0 "Remove sysstat"
  rlPhaseEnd

rlJournalEnd
