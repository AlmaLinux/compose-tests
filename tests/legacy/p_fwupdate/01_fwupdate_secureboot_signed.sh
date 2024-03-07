#!/bin/bash
# This test will verify that fwupdate is correctly signed with correct cert in the CA chain

t_Log "Running $0 -  Verifying that fwupdate is correctly signed with correct cert"

arch=$(uname -m)

if [[ "$centos_ver" -le 8 && "$arch" = "x86_64" ]] ; then
  t_RemovePackage fwupd
  t_InstallPackage pesign fwupdate-efi.x86_64
  pesign --show-signature --in /boot/efi/EFI/almalinux/fwupx64.efi|egrep -q "$grub_sb_token"
  t_CheckExitStatus $?
else
  t_Log "versions more than CentOS 8 - or not x86_64 arch - aren't using fwupdate"
  exit 0
fi

