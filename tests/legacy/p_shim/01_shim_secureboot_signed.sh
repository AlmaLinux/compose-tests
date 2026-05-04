#!/bin/bash
# This test will verify that shim.efi is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that shim.efi is correctly signed with correct cert"

case "$arch" in
  x86_64)  efi_suffix="x64" ;;
  aarch64) efi_suffix="aa64" ;;
  *)       efi_suffix="" ;;
esac

if [[ "$centos_ver" = "7" && "$arch" = "x86_64" ]] ; then
  t_InstallPackage pesign shim
  pesign --show-signature --in /boot/efi/EFI/$vendor/shim.efi | egrep -q "$shim_sb_token"
  t_CheckExitStatus $?
elif [[ "$centos_ver" -ge "8" && ( "$arch" = "x86_64" || "$arch" = "aarch64" ) ]] ; then
  t_InstallPackage pesign shim
  pesign --show-signature --in /boot/efi/EFI/$vendor/shim${efi_suffix}.efi | egrep -q "$shim_sb_token"
  t_CheckExitStatus $?
else
  t_Log "previous versions than CentOS 7 - or unsupported arch ($arch) - aren't using shim/secureboot ... skipping"
  exit 0
fi

