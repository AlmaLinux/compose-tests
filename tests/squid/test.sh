#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart

  rlPhaseStartSetup
  rlRun "dnf install -y squid"
  rlFileBackup /etc/hosts
  localhostname=$(hostname)
  rlRun 'echo "127.0.0.1   $localhostname" >> /etc/hosts'
  rlServiceStart squid
  rlWaitForSocket 3128
  rlPhaseEnd

  rlPhaseStartTest "Should find timestamp"
  rlRun "squidclient -T 2 http://repo.almalinux.org/almalinux/ | grep -q timestamp"
  rlPhaseEnd

  rlPhaseStartCleanup
  rlServiceStop squid
  rlRun "dnf remove -y squid"
  rlFileRestore /etc/hosts
  rlPhaseEnd

rlJournalEnd
