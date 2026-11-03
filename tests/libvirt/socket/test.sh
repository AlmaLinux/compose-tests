#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart

  rlPhaseStartSetup
  rlServiceStart "libvirtd"
  rlPhaseEnd

  rlPhaseStartTest "should get version"
  rlRun "virsh --version"
  rlPhaseEnd

  rlPhaseStartTest "should list domains (empty) on test socket"
  rlRun "virsh -c test:///default list"
  rlPhaseEnd

  rlPhaseStartTest "should list domains (empty) on qemu socket"
  rlRun "virsh -c qemu:///system list"
  rlPhaseEnd

  rlPhaseStartTest "should get nodeinfo on qemu"
  rlRun "virsh -c qemu:///system nodeinfo"
  rlPhaseEnd

  # On s390x libvirt reads the host's system information from /proc/sysinfo,
  # which only an s390x kernel provides: not a container on another one's
  if [ "$(uname -m)" = s390x ] && [ ! -e /proc/sysinfo ]; then
    rlLog "No /proc/sysinfo (s390x on another architecture's kernel): not checking sysinfo"
  else
    rlPhaseStartTest "should get sysinfo on qemu"
    rlRun "virsh -c qemu:///system sysinfo"
    rlPhaseEnd
  fi

  rlPhaseStartTest "should access test socket with python"
  rlRun -s "python3 ./pytestaccess.py"
  rlAssertGrep "TEST" $rlRun_LOG
  rlPhaseEnd

  rlPhaseStartTest "should access qemu socket with python"
  rlRun -s "python3 ./pyqemuaccess.py"
  rlAssertGrep "QEMU" $rlRun_LOG
  rlPhaseEnd

  rlPhaseStartCleanup
  rlServiceStop "libvirtd"
  rlPhaseEnd

rlJournalEnd
