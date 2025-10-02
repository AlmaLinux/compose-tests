#!/bin/bash

t_Log "Running $0 - Checking NVIDIA ABI compatibility"

arch=$(uname -m)

SKIP=1

if [[ "$centos_ver" -ge 9 && ("$arch" == "x86_64" || "$arch" == "aarch64") ]]; then
  SKIP=0
fi

if [[ $SKIP -eq 0 ]]; then
    t_InstallPackage almalinux-release-nvidia-driver kernel kernel-core kernel-modules kernel-modules-core
    t_InstallPackage kmod-nvidia-open
    t_InstallPackage nvidia-open-kmod
    latest_kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V | tail -n 1)
    t_Log "Latest installed kernel: $latest_kernel"

    required_symbols=$(dnf repoquery --requires kmod-nvidia-open | grep '^kernel(' | sort)

    available_symbols=$(rpm -q --provides kernel-core-$latest_kernel kernel-modules-$latest_kernel kernel-modules-core-$latest_kernel | grep '^kernel(' | sort | uniq)
    provided_by_module=""
    for mod in $(rpm -ql kmod-nvidia-open | grep '\.ko$'); do
        provided_by_module+="$(nm -u $mod 2>/dev/null | awk '{print "kernel(" $2 ")"}')"$'\n'
    done
    provided_by_module=$(t_Log "$provided_by_module" | sort -u)

    check_list=$(comm -23 <(t_Log "$required_symbols") <(t_Log "$provided_by_module"))

    missing=$(comm -23 <(t_Log "$check_list") <(t_Log "$available_symbols"))

    if [[ -n "$missing" ]]; then
        t_Log "ERROR: Missing kernel symbols for NVIDIA module:"
        t_Log "$missing"
        exit 1
    else
        t_Log "SUCCESS: All required NVIDIA symbols are provided by kernel $latest_kernel"
        exit 0
    fi
else
  t_Log "SKIP - ${centos_ver} on ${arch} is not supported"
  exit 0
fi
