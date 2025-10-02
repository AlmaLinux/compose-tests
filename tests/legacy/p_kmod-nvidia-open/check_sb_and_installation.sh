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

echo "Running $0 - Checking NVIDIA module dependencies against latest kernel"

latest_kernel=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V | tail -n 1)
echo "Latest installed kernel: $latest_kernel"

required_symbols=$(dnf repoquery --requires kmod-nvidia-open | grep '^kernel(' | sort)

kernel_symvers=$(rpm -q --provides kernel-core-$latest_kernel | grep '^kernel(' | sort)

available_symbols=$(awk '{print $2}' "$kernel_symvers" | sort | uniq | sed 's/^/kernel(/;s/$/)/')
provided_by_module=""
for mod in $(rpm -ql kmod-nvidia-open | grep '\.ko$'); do
    provided_by_module+="$(nm -u $mod 2>/dev/null | awk '{print "kernel(" $2 ")"}')"$'\n'
done
provided_by_module=$(echo "$provided_by_module" | sort -u)

# Отфильтровываем символы, которые модуль сам себе «несёт»
check_list=$(comm -23 <(echo "$required_symbols") <(echo "$provided_by_module"))

# Сравнение: должны совпадать
missing=$(comm -23 <(echo "$check_list") <(echo "$available_symbols"))

if [[ -n "$missing" ]]; then
    echo "ERROR: Missing kernel symbols for NVIDIA module:"
    echo "$missing"
    exit 1
else
    echo "SUCCESS: All required NVIDIA symbols are provided by kernel $latest_kernel"
fi

  exit 0
fi
