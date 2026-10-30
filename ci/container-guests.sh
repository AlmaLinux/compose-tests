#!/bin/bash
# Start AlmaLinux containers of an architecture with podman, one per name in
# $guests, systemd as PID 1: natively on a runner of that architecture, or
# run by QEMU user-mode emulation (the qemu-<arch> binfmt_misc handler must be
# registered) on another one. Waits until systemd has booted every container.
# Run commands in one with 'podman exec <guest> ...'; remove them with
# 'podman rm -f -t 0 <guest>': they do not stop on systemd's stop signal under
# emulation.
#
#   guests='almalinux-0 almalinux-1' ci/container-guests.sh ppc64le docker.io/almalinux/9-init:latest
#
# Extra 'podman run' options can be given in $podman_run_options.

usage="usage: $0 ARCH IMAGE"
arch=${1:?${usage}}
image=${2:?${usage}}
set -e -o pipefail

if [ "$(uname -m)" != "${arch}" ] && [ ! -e "/proc/sys/fs/binfmt_misc/qemu-${arch}" ]; then
  echo "[Error] No qemu-${arch} binfmt_misc handler: ${arch} binaries cannot run here" >&2
  exit 1
fi

podman pull -q --platform "linux/${arch}" "${image}" > /dev/null

for guest in ${guests:?}; do
  podman run -d --name "${guest}" --hostname "${guest}" --platform "linux/${arch}" \
    --systemd=always ${podman_run_options:-} "${image}" > /dev/null
done

for guest in ${guests}; do
  for i in $(seq 1 60); do
    state=$(podman exec "${guest}" systemctl is-system-running 2> /dev/null) || true
    case "${state}" in running|degraded) break ;; esac
    if [ "${i}" -eq 60 ]; then
      echo "[Error] ${guest}: systemd not up after 10 minutes ('${state}')" >&2
      exit 1
    fi
    sleep 10
  done

  # Under emulation the units with credentials (ImportCredential=) fail at
  # boot with 243/CREDENTIALS: QEMU does not translate the mount calls systemd
  # sets them up with. Run systemd-sysusers and systemd-tmpfiles ourselves,
  # give journald (it imports credentials since AlmaLinux 10) a copy of its
  # unit without them, and start again what failed at boot, D-Bus with it.
  echo "[Debug] ${guest}: failed at boot: $(podman exec "${guest}" systemctl --failed --no-legend --plain | awk '{print $1}' | xargs)"
  # The services installed later fail the same way: libvirtd and virtsecretd
  # load an encrypted credential since libvirt 12.8 (AlmaLinux Kitten). Clear
  # their credentials with a drop-in. Not with a top-level one for every
  # service: under s390x emulation systemd reports a unit with a drop-in as
  # changed on disk, and postgresql-setup then refuses to initialize the
  # database.
  if [ "$(uname -m)" != "${arch}" ]; then
    podman exec "${guest}" sh -c '
      for unit in libvirtd virtsecretd; do
        mkdir -p /etc/systemd/system/${unit}.service.d
        printf "%s\n" "[Service]" LoadCredential= LoadCredentialEncrypted= \
          > /etc/systemd/system/${unit}.service.d/99-emulated-no-credentials.conf
      done
    '
  fi
  podman exec "${guest}" sh -c '
    systemd-sysusers
    systemd-tmpfiles --create --remove --boot --exclude-prefix=/dev
    unit=/usr/lib/systemd/system/systemd-journald.service
    if grep -q "^ImportCredential=" "${unit}"; then
      sed "/^ImportCredential=/d" "${unit}" > /etc/systemd/system/systemd-journald.service
    fi
    systemctl daemon-reload
    failed=$(systemctl --failed --no-legend --plain | awk "{print \$1}" |
      grep -vE "^systemd-(sysusers|tmpfiles-setup|tmpfiles-setup-dev|tmpfiles-setup-dev-early|firstboot)\.service$")
    systemctl reset-failed
    [ -z "${failed}" ] || systemctl restart ${failed}
  ' || true

  echo "[Debug] ${guest}: $(podman exec "${guest}" sh -c 'echo "$(uname -m), $(cat /etc/almalinux-release), systemd $(systemctl is-system-running)"')"
  echo "[Debug] ${guest}: still failed: $(podman exec "${guest}" systemctl --failed --no-legend --plain | awk '{print $1}' | xargs)"
done
