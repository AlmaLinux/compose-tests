#!/bin/bash -e

source ../functions.sh

# osbuild-composer ships x86_64 (v3-baseline) repo definitions only — there is
# no x86_64_v2 arch block in the repositories JSON, and the build chroot pulls
# v3 glibc which aborts on a v2 host. Detect the v2 variant once via the
# installed glibc arch tag and let child scripts react accordingly.
# almalinux-kitten ships osbuild-composer with x86_64_v2 support, so the
# workaround does not apply on any kitten release and the tests must run
# normally there.
if [ "$(rpm -q --qf '%{ARCH}' glibc)" = "x86_64_v2" ] && ! t_IsKitten; then
    export OSBUILD_X86_64_V2=1
fi

./0-install_osbuild.sh
./1-verify_osbuild.sh
./osbuild_test.sh
