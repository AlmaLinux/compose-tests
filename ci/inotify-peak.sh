#!/bin/bash
# Count the inotify instances root's processes hold every 5 seconds, until
# killed, and keep the largest count in FILE: on its first line the count and
# when, then how many each process held and where it ran (a container or the
# runner). Run as root, so that every process can be seen.
#
#   sudo ci/inotify-peak.sh /tmp/inotify-peak & ...; sudo kill $!; cat /tmp/inotify-peak

file=${1:?usage: $0 FILE}
# Containers' IDs and names: a process' cgroup tells the container it runs in
containers=$(podman ps --no-trunc --format '{{.ID}} {{.Names}}' 2> /dev/null)
peak=0
while :; do
  fds=$(find /proc/[0-9]*/fd -user 0 -lname 'anon_inode:inotify' 2> /dev/null)
  count=$(grep -c . <<< "${fds}")
  if [ "${count}" -gt "${peak}" ]; then
    peak=${count}
    {
      echo "${peak} at $(date -u +%H:%M:%S)"
      cut -d/ -f3 <<< "${fds}" | sort | uniq -c | while read -r n pid; do
        id=$(grep -o 'libpod-[0-9a-f]\{64\}' "/proc/${pid}/cgroup" 2> /dev/null | head -1)
        where=$(awk -v id="${id#libpod-}" '$1 == id {print $2}' <<< "${containers}")
        printf '%s\t%s\t%s\n' "${n}" "$(cat "/proc/${pid}/comm" 2> /dev/null || echo '(gone)')" "${where:-runner}"
      done | awk -F '\t' '{n[$3 "\t" $2] += $1} END {for (k in n) print n[k] "\t" k}' | sort -k2,2 -k1,1rn
    } > "${file}.new" && mv "${file}.new" "${file}"
  fi
  sleep 5
done
