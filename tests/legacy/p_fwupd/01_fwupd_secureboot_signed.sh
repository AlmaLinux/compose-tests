#!/bin/bash
# This test will verify that fwupd is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that fwupd is correctly signed with correct cert"

arch=$(uname -m)

case "$arch" in
  x86_64)  efi_suffix="x64" ;;
  aarch64) efi_suffix="aa64" ;;
  *)       efi_suffix="" ;;
esac

if [[ "$arch" = "aarch64" && "$centos_ver" -le 9 ]] ; then
  t_Log "AlmaLinux $centos_ver aarch64 does not ship a signed fwupd EFI binary ... skipping"
  exit 0
fi

if [[ "$centos_ver" -ge 7 && ( "$arch" = "x86_64" || "$arch" = "aarch64" ) ]] ; then
  t_InstallPackage pesign fwupd
  [ $centos_ver -eq 10 ] && t_InstallPackage fwupd-efi
  pesign --show-signature --in /usr/libexec/fwupd/efi/fwupd${efi_suffix}.efi.signed|egrep -q "$grub_sb_token"
  t_CheckExitStatus $?
else
  t_Log "previous versions than CentOS 7 - or unsupported arch ($arch) - aren't using secureboot ... skipping"
  exit 0
fi
