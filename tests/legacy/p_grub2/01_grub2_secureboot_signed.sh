#!/bin/bash
# This test will verify that grub2-efi is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that grub2-efi is correctly signed with correct cert"

arch=$(uname -m)

case "$arch" in
  x86_64)
    efi_suffix="x64"
    grub_pkg="grub2-efi-x64"
    ;;
  aarch64)
    efi_suffix="aa64"
    grub_pkg="grub2-efi-aa64"
    ;;
  *)
    efi_suffix=""
    grub_pkg=""
    ;;
esac

if [[ "$centos_ver" -ge 7 && ( "$arch" = "x86_64" || "$arch" = "aarch64" ) ]] ; then
  t_InstallPackage pesign $grub_pkg
  pesign --show-signature --in /boot/efi/EFI/$vendor/grub${efi_suffix}.efi|egrep -q "$grub_sb_token"
  t_CheckExitStatus $?
else
  t_Log "previous versions than CentOS 7 - or unsupported arch ($arch) - aren't using secureboot ... skipping"
  exit 0
fi
