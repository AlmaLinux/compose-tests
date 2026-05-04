#!/bin/bash
# This test will verify that fwupdate is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that fwupdate is correctly signed with correct cert"

arch=$(uname -m)

case "$arch" in
  x86_64)  efi_suffix="x64" ;;
  aarch64) efi_suffix="aa64" ;;
  *)       efi_suffix="" ;;
esac

if [[ "$centos_ver" -le 8 && ( "$arch" = "x86_64" || "$arch" = "aarch64" ) ]] ; then
  t_RemovePackage fwupd
  t_InstallPackage pesign fwupdate-efi.${arch}
  pesign --show-signature --in /boot/efi/EFI/almalinux/fwup${efi_suffix}.efi|egrep -q "$grub_sb_token"
  t_CheckExitStatus $?
else
  t_Log "versions more than CentOS 8 - or unsupported arch ($arch) - aren't using fwupdate"
  exit 0
fi

