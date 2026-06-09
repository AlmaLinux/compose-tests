#!/bin/bash
# This test will verify that kmod-nvidia-open is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that kmod-nvidia-open is correctly signed with correct cert"

# Derive the arch from the glibc RPM rather than `uname -m`: on x86_64_v2
# composes `uname -m` still reports plain "x86_64", but the NVIDIA driver is
# not built for x86_64_v2, so the package arch (x86_64_v2) is what we must
# match on to skip those runners.
arch=$(rpm -q --queryformat '%{ARCH}' glibc)

SKIP=1

if [[ ("$centos_ver" -eq 9 || "$centos_ver" -eq 10) && ("$arch" == "x86_64" || "$arch" == "aarch64") ]]; then
  SKIP=0
fi


if [[ $SKIP -eq 0 ]]; then
    t_InstallPackage almalinux-release-nvidia-driver
    t_InstallPackage kmod-nvidia-open
    t_InstallPackage nvidia-open-kmod

    if [[ "$arch" == "x86_64" ]]; then
        # Derive the module names from the package's .ko files (strip the
        # path and the .ko extension). Using the bare names means modinfo
        # resolves them against the running kernel's modules.dep, so we also
        # verify they are visible from the running kernel, not just that the
        # package ships signed .ko files.
        MODULES=$(rpm -ql kmod-nvidia-open | grep '\.ko$' | sed 's#.*/##; s#\.ko$##')
    else
        MODULES=$(rpm -ql kmod-nvidia-open | grep '\.ko$')
    fi

    for i in $MODULES; do
        modinfo $i | grep $kmod_nvidia_sb_key
        t_CheckExitStatus $?
    done

    rpm -qa | grep kmod-nvidia-open
    t_CheckExitStatus $?
else

  exit 0
fi
