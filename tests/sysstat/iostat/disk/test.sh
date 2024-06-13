#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

rlJournalStart

  rlPhaseStartSetup
  rlRun "yum install -y sysstat" 0 "Installing sysstat"
  rlRun 'TmpDir=$(mktemp -d)' 0 'Creating tmp directory' # no-reboot
  rlRun "pushd $TmpDir"
  rlRun "echo 1 > /proc/sys/vm/drop_caches" 0 "Clear out the pagecache to get an accurate reading"
  rlRun "drive=/dev/\$(lsblk -o NAME -n -i -r | head -1)" 0 "Capture a storage device name"

  # dd options
  rlRun "bs=4196"
  rlRun "count=10100"
  rlRun "sum=\$(expr $bs \* $count / 1024)"
  rlPhaseEnd

  rlPhaseStartTest
  rlRun "/usr/bin/iostat -d 1 5 $drive > output 2>&1 &" 0 "Run iostat on the device"
  rlRun "sleep 1" 0 "Time for iostat booting" 
  rlRun "/bin/dd if=$drive of=/dev/null bs=$bs count=$count" 0 "Generate some read traffic"
  rlRun "sleep 6" 0 "Give iostat a chance to log our task"
  rlRun "cat output" 0 "Display captured output"
  rlRun "kbytes_read=\$(awk '\$6 ~ /[0-9]/ {NR>1 && sum+=\$6} END {print int(sum)}' output)" 0 "Extract the disk utilization"
  rlAssertNotEquals "Should register disk read utilization" $kbytes_read 0
  rlPhaseEnd

  rlPhaseStartCleanup
  rlRun "popd"
  rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
  rlRun "yum remove -y sysstat" 0 "Removing sysstat"
  rlPhaseEnd

rlJournalEnd
