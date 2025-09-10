#!/bin/bash
# This test will verify that kmod-nvidia-open is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that kmod-nvidia-open is correctly signed with correct cert"

arch=$(uname -m)

SKIP=1

if [[ "$centos_ver" -eq 9 && ("$arch" == "x86_64" || "$arch" == "aarch64") ]]; then
  SKIP=0
fi

if [[ "$centos_ver" -eq 10 && "$arch" != "x86_64" ]]; then
  SKIP=0
fi


if [[ $SKIP -eq 0 ]]; then
    t_InstallPackage almalinux-release-nvidia-driver
    t_InstallPackage kmod-nvidia-open
    t_InstallPackage nvidia-open-kmod

    for i in $(rpm -ql kmod-nvidia-open | grep '\.ko$'); do
        modinfo $i | grep $kmod_nvidia_sb_key
        t_CheckExitStatus $?
    done

    rpm -qa | grep kmod-nvidia-open
    t_CheckExitStatus $?
else

  exit 0
fi
