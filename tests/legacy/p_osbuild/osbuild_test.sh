#!/bin/bash
# Yuriy Kohut <ykohut@almalinux.org>

# Blueprint name and TOML file
blueprint=test-base
test_toml=${blueprint}.toml
# Resulted image type
image_type=qcow2
check_type=qcow

# Maximum amount of time (wait_sec*wait_count) to wait for the image to be created
wait_sec=20
wait_count=45

t_Log "Running $0 - osbuild: start to build '$blueprint' image, type '$image_type'"

if [ "$CONTAINERTEST" -eq "1" ]; then
    t_Log "Running in container -> SKIP"
    exit 0
fi

# osbuild-composer ships x86_64 (v3-baseline) repo definitions only; the build
# chroot pulls v3 glibc which aborts on a v2 host with "CPU does not support
# x86-64-v3". Detect the v2 variant via the installed glibc arch tag.
if [ "$(rpm -q --qf '%{ARCH}' glibc)" = "x86_64_v2" ]; then
    t_Log "osbuild-composer lacks x86_64_v2 repo definitions -> SKIP"
    exit 0
fi

t_Log "Running $0 - osbuild: create '$test_toml'"
cat > $test_toml <<EOF
name = "$blueprint"
description = "A base system"
version = "0.0.1"

[[packages]]
name = "bash"
version = "*"
EOF

t_Log "Running $0 - osbuild: push '$test_toml' to blueprints"
composer-cli blueprints push $test_toml || t_CheckExitStatus $?

t_Log "Running $0 - osbuild: depsolve the '$blueprint' blueprint"
composer-cli blueprints depsolve $blueprint || t_CheckExitStatus $?

t_Log "Running $0 - osbuild: start building '$blueprint' blueprint"
compose_id=$( composer-cli compose start $blueprint $image_type \
| grep -E 'Compose|added|queue' \
| sed 's/^Compose \+\(.\+\) \+added \+to \+the \+queue$/\1/g' )

test -n "$compose_id" || t_CheckExitStatus $?

t_Log "Running $0 - osbuild: wait $(($wait_sec*$wait_count)) seconds (maximum) for the image (ID '$compose_id') to be created ..."
count=1
while true; do
    composer-cli compose status | grep $compose_id | grep 'FINISHED' >/dev/null 2>&1
    [ $? -eq 0 ] && break
    # Fail the test if the image build FAILED
    composer-cli compose status | grep $compose_id | grep 'FAILED' >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        t_Log "$( composer-cli compose log $compose_id )"
        t_CheckExitStatus 1
    fi
    sleep ${wait_sec}s
    count=$(($count+1))
    [ $count -gt $wait_count ] && break
done
test $count -le $wait_count || t_CheckExitStatus $?

t_Log "Running $0 - osbuild: the creation completed in ~ $(($wait_sec*$count)) seconds."

t_Log "Running $0 - osbuild: download the resulting image file ..."
composer-cli compose image $compose_id >/dev/null || t_CheckExitStatus $?

t_Log "Running $0 - osbuild: test the ${compose_id}-disk.${image_type} image file"
file --brief ${compose_id}-disk.${image_type} | grep -i $check_type >/dev/null
ret_val=$?

t_Log "Running $0 - osbuild: clean up"
rm -f ${compose_id}-disk.${image_type} $test_toml
composer-cli compose delete $compose_id
composer-cli blueprints delete $blueprint

t_CheckExitStatus $ret_val
