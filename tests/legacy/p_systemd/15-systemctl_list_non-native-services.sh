#!/bin/bash
# Author: Athmane Madjoudj <athmanem@gmail.com>
#         Rene Diepstraten <rene@renediepstraten.nl>

if [ "$CONTAINERTEST" -eq "1" ]; then
    t_Log "Running in container -> SKIP"
    exit 0
fi

[ ${centos_ver} -lt 7 ] && exit
t_Log "Running $0 - Checking if systemctl can check if a non-native service is enabled"

if ! systemctl list-unit-files --all -t service --full --no-legend "kdump.service" >/dev/null; then
    t_Log "The kdump.service not found -> SKIP"
    exit 0
fi
systemctl is-enabled kdump.service 2> /dev/null | grep -q -E 'enabled|disabled'

t_CheckExitStatus $?
