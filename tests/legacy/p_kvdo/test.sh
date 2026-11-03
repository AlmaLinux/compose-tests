#!/bin/bash -e

source ../functions.sh

if [ "$CONTAINERTEST" -eq "1" ]; then
    t_Log "Running $0 - kvdo is a kernel module: running in container -> SKIP"
    exit 0
fi
./0-install_kvdo.sh
./kvdo_runtest.sh
./check_sb.sh