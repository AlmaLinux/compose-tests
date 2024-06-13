#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1

tools_versions_test=(
    bpf-bindsnoop
    bpf-biolatency
    bpf-biopattern
    bpf-biosnoop
    bpf-biostacks
    bpf-bitesize
    bpf-cachestat
    bpf-capable
    bpf-cpudist
    bpf-cpufreq
    bpf-drsnoop
    bpf-execsnoop
    bpf-exitsnoop
    bpf-ext4dist
    bpf-ext4slower
    bpf-filelife
    bpf-filetop
    bpf-fsdist
    bpf-fsslower
    bpf-funclatency
    bpf-gethostlatency
    bpf-hardirqs
    bpf-killsnoop
    bpf-klockstat
    bpf-ksnoop
    bpf-llcstat
    bpf-mdflush
    bpf-mountsnoop
    bpf-nfsdist
    bpf-nfsslower
    bpf-numamove
    bpf-offcputime
    bpf-oomkill
    bpf-opensnoop
    bpf-readahead
    bpf-runqlat
    bpf-runqlen
    bpf-runqslower
    bpf-sigsnoop
    bpf-softirqs
    bpf-solisten
    bpf-statsnoop
    bpf-syscount
    bpf-tcpconnect
    bpf-tcpconnlat
    bpf-slabratetop
    bpf-tcplife
    bpf-tcprtt
    bpf-tcpsynbl
    bpf-tcptracer
    bpf-tcptop
    bpf-tcpstates
    bpf-vfsstat
    bpf-xfsdist
    bpf-xfsslower
    bpf-wakeuptime
)

rlJournalStart
  rlPhaseStartSetup
  rlRun "dnf -y install libbpf-tools"
  rlPhaseEnd

for tool in "${tools_versions_test[@]}"; do
  rlPhaseStartTest "${tool} get version"
  rlRun "${tool} -V"
  rlPhaseEnd
done

  rlPhaseStartTest "bpf-biolatency basic tracing"
  rlRun "bpf-biolatency 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-biopattern basic tracing"
  rlRun "bpf-biopattern 1 1"
  rlPhaseEnd

#  rlPhaseStartTest "bpf-biosnoop basic tracing"
#  rlRun "bpf-biosnoop 1"
#  rlPhaseEnd

#  rlPhaseStartTest "bpf-biostacks basic tracing"
#  rlRun "bpf-biostacks 1"
#  rlPhaseEnd

  rlPhaseStartTest "bpf-bitesize basic tracing"
  rlRun "bpf-bitesize 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-cachestat basic tracing"
  rlRun "bpf-cachestat 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-cpudist basic tracing"
  rlRun "bpf-cpudist 1 1"
  rlPhaseEnd

#  rlPhaseStartTest "bpf-cpufreq basic tracing"
#  rlRun "bpf-cpufreq -d 1"
#  rlPhaseEnd

  rlPhaseStartTest "bpf-drsnoop basic tracing"
  rlRun "bpf-drsnoop -d 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-filetop basic tracing"
  rlRun "bpf-filetop 1 1 --noclear"
  rlPhaseEnd

  rlPhaseStartTest "bpf-fsdist basic tracing"
  rlRun "bpf-fsdist -t \$(df -T \$(pwd) | tail -1 | awk '{print \$2}') 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-fsslower basic tracing"
  rlRun "bpf-fsslower -t \$(df -T \$(pwd) | tail -1 | awk '{print \$2}') -d 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-funclatency basic tracing"
  rlRun "bpf-funclatency -i 1 -d 1 vfs_read"
  rlPhaseEnd

  rlPhaseStartTest "bpf-hardirqs basic tracing"
  rlRun "bpf-hardirqs 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-klockstat basic tracing"
  rlRun "bpf-klockstat -d 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-llcstat basic tracing"
  rlRun "bpf-llcstat 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-offcputime basic tracing"
  rlRun "bpf-offcputime 1"
  rlPhaseEnd

#  rlPhaseStartTest "bpf-opensnoop basic tracing"
#  rlRun "bpf-opensnoop -x -d 1"
#  rlPhaseEnd

#  rlPhaseStartTest "bpf-readahead basic tracing"
#  rlRun "bpf-readahead -d 1"
#  rlPhaseEnd

  rlPhaseStartTest "bpf-runqlat basic tracing"
  rlRun "bpf-runqlat 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-runqlen basic tracing"
  rlRun "bpf-runqlen 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-slabratetop basic tracing"
  rlRun "bpf-slabratetop 1 1 --noclear"
  rlPhaseEnd

  rlPhaseStartTest "bpf-softirqs basic tracing"
  rlRun "bpf-softirqs 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-syscount basic tracing"
  rlRun "bpf-syscount -d 1 -T 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-tcprtt basic tracing"
  rlRun "bpf-tcprtt -d 1 -i 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-tcptop basic tracing"
  rlRun "bpf-tcptop 1 1 --noclear"
  rlPhaseEnd

  rlPhaseStartTest "bpf-tcpsynbl basic tracing"
  rlRun "bpf-tcpsynbl 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-vfsstat basic tracing"
  rlRun "bpf-vfsstat 1 1"
  rlPhaseEnd

  rlPhaseStartTest "bpf-wakeuptime basic tracing"
  rlRun "bpf-wakeuptime 1"
  rlPhaseEnd

  rlPhaseStartCleanup
  rlRun "dnf remove -y libbpf-tools"
  rlPhaseEnd

rlJournalEnd
