#!/bin/bash
# Yuriy Kohut <ykohut@almalinux.org>

# Blueprint name and TOML file
blueprint=test-base
test_toml=${blueprint}.toml
# Resulted image type
image_type=qcow2
check_type=qcow

# Maximum wall-clock time (seconds) to wait for the image to be created,
# how often to poll, and a hard cap on each individual composer-cli call so a
# wedged osbuild-composer backend can never block the loop indefinitely.
wait_max=900
poll_sec=20
cli_timeout=60

t_Log "Running $0 - osbuild: start to build '$blueprint' image, type '$image_type'"

if [ "$CONTAINERTEST" -eq "1" ]; then
    t_Log "Running in container -> SKIP"
    exit 0
fi

# The build chroot pulls v3 glibc which aborts on a v2 host with "CPU does not
# support x86-64-v3"; OSBUILD_X86_64_V2 is exported by test.sh.
if [ -n "$OSBUILD_X86_64_V2" ]; then
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
compose_id=$( timeout ${cli_timeout} composer-cli compose start $blueprint $image_type \
| grep -E 'Compose|added|queue' \
| sed 's/^Compose \+\(.\+\) \+added \+to \+the \+queue$/\1/g' )

test -n "$compose_id" || t_CheckExitStatus $?

# Poll until the build FINISHED/FAILED or the wall-clock deadline is reached.
# Each composer-cli call is bounded by 'timeout', and the loop is bounded by an
# absolute deadline, so a hung backend fails the test fast instead of blocking
# forever (the old count-based guard only counted iterations, not the time spent
# inside a blocked composer-cli call).
t_Log "Running $0 - osbuild: wait ${wait_max} seconds (maximum) for the image (ID '$compose_id') to be created ..."
start_time=$( date +%s )
deadline=$(( start_time + wait_max ))
while true; do
    status=$( timeout ${cli_timeout} composer-cli compose status 2>/dev/null | grep "$compose_id" )
    case "$status" in
        *FINISHED*) break ;;
        # Fail the test if the image build FAILED
        *FAILED*)
            t_Log "$( timeout ${cli_timeout} composer-cli compose log $compose_id )"
            t_CheckExitStatus 1
            ;;
    esac
    if [ "$( date +%s )" -ge "$deadline" ]; then
        t_Log "Running $0 - osbuild: timed out after ${wait_max} seconds waiting for the image"
        t_CheckExitStatus 1
    fi
    sleep ${poll_sec}s
done

t_Log "Running $0 - osbuild: the creation completed in ~ $(( $( date +%s ) - start_time )) seconds."

t_Log "Running $0 - osbuild: download the resulting image file ..."
timeout ${cli_timeout} composer-cli compose image $compose_id >/dev/null || t_CheckExitStatus $?

t_Log "Running $0 - osbuild: test the ${compose_id}-disk.${image_type} image file"
file --brief ${compose_id}-disk.${image_type} | grep -i $check_type >/dev/null
ret_val=$?

t_Log "Running $0 - osbuild: clean up"
rm -f ${compose_id}-disk.${image_type} $test_toml
composer-cli compose delete $compose_id
composer-cli blueprints delete $blueprint

t_CheckExitStatus $ret_val
