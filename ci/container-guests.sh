#!/bin/bash
# Start AlmaLinux containers of an architecture with podman, one per name in
# $guests, systemd as PID 1: natively on a runner of that architecture, or
# run by QEMU user-mode emulation (the qemu-<arch> binfmt_misc handler must be
# registered) on another one. Waits until systemd has booted every container
# and checks that the containers resolve names.
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

# The containers reach the runner's network through podman's default one,
# 10.88.0.0/16. Some runners are in it themselves (an s390x runner's DNS server
# was 10.88.92.1): the containers then send to the bridge what is for them, and
# cannot resolve names. Use the first subnet that is none of the runner's
# routes, nameservers included, on a network of our own if it is not podman's.
subnet=$(python3 -I - <<'EOF'
import ipaddress, json, re, subprocess
routes = json.loads(subprocess.run(["ip", "-j", "-4", "route", "show", "table", "all"],
                                   capture_output=True, text=True, check=True).stdout)
used = [ipaddress.ip_network(r["dst"], strict=False) for r in routes
        if r.get("dst", "default") != "default" and not r.get("dev", "").startswith("podman")]
for resolv in ("/etc/resolv.conf", "/run/systemd/resolve/resolv.conf"):
    try:
        used += [ipaddress.ip_network(ns) for ns in
                 re.findall(r"^nameserver\s+([0-9.]+)\s*$", open(resolv).read(), re.M)]
    except OSError:
        pass
candidates = [f"10.{n}.0.0/16" for n in range(88, 100)] + ["172.30.0.0/16", "192.168.200.0/24"]
print(next(c for c in map(ipaddress.ip_network, candidates)
           if not any(c.overlaps(u) for u in used if not u.is_loopback)))
EOF
)
network=podman
if [ "${subnet}" != 10.88.0.0/16 ]; then
  network=compose-tests
  echo "[Debug] podman's network 10.88.0.0/16 overlaps the runner's: the containers get ${subnet}"
  podman network exists "${network}" ||
    podman network create --disable-dns --subnet "${subnet}" "${network}" > /dev/null
fi

for guest in ${guests:?}; do
  podman run -d --name "${guest}" --hostname "${guest}" --platform "linux/${arch}" \
    --network "${network}" --systemd=always ${podman_run_options:-} "${image}" > /dev/null
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

# The containers resolve names with the runner's upstream DNS servers, through
# podman's network. On the native s390x runner that failed now and then for a
# whole job: dnf then waited 2.5 minutes for the first name. Check it, show
# why it fails, and reload podman's network (its firewall rules) once.
dns_name=mirrors.almalinux.org

dns_works() {
  for guest in ${guests}; do
    podman exec "${guest}" timeout 15 getent hosts "${dns_name}" > /dev/null || return 1
  done
}

dns_debug() {
  echo "[Debug] runner: ${dns_name} $(getent hosts "${dns_name}" > /dev/null && echo resolves || echo 'does not resolve'), nameservers: $(awk '/^nameserver/ {print $2}' /etc/resolv.conf | xargs)"
  if [ -r /run/systemd/resolve/resolv.conf ]; then
    echo "[Debug] runner: systemd-resolved upstream nameservers: $(awk '/^nameserver/ {print $2}' /run/systemd/resolve/resolv.conf | xargs)"
  fi
  echo "[Debug] podman network: $(podman network inspect "${network}" --format '{{.Driver}} {{.NetworkInterface}} {{range .Subnets}}{{.Subnet}} {{end}}dns_enabled={{.DNSEnabled}}'), backend $(podman info --format '{{.Host.NetworkBackend}}'), ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)"
  for guest in ${guests}; do
    echo "[Debug] ${guest}: nameservers: $(podman exec "${guest}" awk '/^nameserver/ {print $2}' /etc/resolv.conf | xargs)," \
      "${dns_name} $(podman exec "${guest}" timeout 15 getent hosts "${dns_name}" > /dev/null && echo resolves || echo 'does not resolve')," \
      "HTTPS to 1.1.1.1: $(podman exec "${guest}" curl -s -o /dev/null --max-time 15 -w '%{http_code}' https://1.1.1.1/ || echo failed)"
  done
}

for i in $(seq 1 4); do
  dns_works && break
  if [ "${i}" -eq 4 ]; then
    echo "[Warning] The containers cannot resolve ${dns_name}: reloading podman's network"
    dns_debug
    podman network reload --all > /dev/null
    if dns_works; then
      echo "[Debug] The containers resolve ${dns_name} after reloading podman's network"
      break
    else
      echo "[Error] The containers still cannot resolve ${dns_name}" >&2
      dns_debug
      exit 1
    fi
  fi
  sleep 15
done
