#!/bin/bash
. /usr/share/beakerlib/beakerlib.sh || exit 1
 
 
#!/bin/bash
# Author: Iain Douglas <centos@1n6.org.uk>

# Include BeakerLib
. /usr/share/beakerlib/beakerlib.sh || exit 1

OUTDIR=$(mktemp --directory)
INDIR=$(mktemp --directory)
PASSDIR=$(mktemp --directory)

rlJournalStart
    rlPhaseStartSetup
    rlRun "mkdir -p $OUTDIR $INDIR $PASSDIR" 0 "Creating working directories"
    rlPhaseEnd

    rlPhaseStartTest "Basic copy out test"
    rlRun "ls | cpio -o > $OUTDIR/cpio.out" 0 "Creating cpio archive from current directory"
    rlAssertExists "$OUTDIR/cpio.out"
    rlPhaseEnd

    rlPhaseStartTest "Basic copy in test"
    rlRun "pushd $INDIR"
    rlRun "cpio -i < $OUTDIR/cpio.out" 0 "Extracting cpio archive into $INDIR"
    rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "Basic pass through test"
    rlRun "pushd $INDIR"
    rlRun "find . | cpio -pd $PASSDIR" 0 "Copying files via cpio pass-through mode into $PASSDIR"
    rlRun "popd"
    rlPhaseEnd

    rlPhaseStartTest "Verify pass-through and extracted directories match"
    rlRun "diff $PASSDIR $INDIR" 0 "Checking that $PASSDIR and $INDIR contents are identical"
    rlPhaseEnd

    rlPhaseStartCleanup
    rlRun "rm -rf $INDIR" 0 "Removing cpio temp in directory"
    rlRun "rm -rf $OUTDIR" 0 "Removing cpio temp out directory"
    rlRun "rm -rf $PASSDIR" 0 "Removing cpio temp pass directory"
    rlPhaseEnd
rlJournalEnd
