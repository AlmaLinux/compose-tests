#!/bin/bash
# Enabling a module whose batch is split fails outright (exit 1), so check the
# perl modules against every perl stream, not just the default one.
#
# 'dnf module enable perl-DBI:1.641' also enables the perl stream its context
# requires, so every stream is reset before the next one is checked and the
# system is left as it was found.
#
# dnf is slow to start and re-reads the repository metadata every time, so the
# modules are enabled in a single call per stream. That is the green path; only
# when it fails are they retried one by one, to name the module at fault.

t_SkipReleaseLessThan 8 'no modularity'

t_Log "Running $0 - enabling every perl module stream against every perl stream"

perl_modules="perl-DBI:1.641 perl-YAML:1.24 perl-FCGI:0.78 perl-IO-Socket-SSL:2.066
              perl-App-cpanminus:1.7044 perl-DBD-MySQL:4.046 perl-DBD-Pg:3.7
              perl-DBD-SQLite:1.58 perl-libwww-perl:6.34"

# every stream the checks below can enable, directly or as a dependency
perl_streams="perl perl-DBI perl-YAML perl-FCGI perl-IO-Socket-SSL
              perl-App-cpanminus perl-DBD-MySQL perl-DBD-Pg perl-DBD-SQLite
              perl-libwww-perl"

# one module listing for everything below, instead of a dnf call per module
module_list=$(dnf -q module list 2>/dev/null)
streams=$(printf '%s\n' "${module_list}" | awk '$1 == "perl" {print $2}')

available=
for module in $perl_modules; do
    if printf '%s\n' "${module_list}" | awk '{print $1}' | grep -qx "${module%%:*}"; then
        available="${available} ${module}"
    fi
done

if [ -z "${available}" ]; then
    t_Log "  no perl modules in this release, nothing to check"
    t_CheckExitStatus 0
    exit 0
fi

ret_val=0
for stream in $streams; do
    dnf -y module reset $perl_streams &>/dev/null
    if ! dnf -y module enable "perl:${stream}" &>/tmp/enable_perl_${stream}.log; then
        t_Log "  perl:${stream}: FAILED to enable"
        ret_val=1
        continue
    fi

    if dnf -y module enable $available &>/tmp/enable_all_${stream}.log; then
        t_Log "  perl:${stream}: all perl modules OK"
        continue
    fi

    # retry one at a time so the log names the module at fault
    for module in $available; do
        name=${module%%:*}
        dnf -y module reset $perl_streams &>/dev/null
        dnf -y module enable "perl:${stream}" &>/dev/null
        if dnf -y module enable "$module" &>/tmp/enable_${name}.log; then
            t_Log "  perl:${stream} + ${module}: OK"
        else
            t_Log "  perl:${stream} + ${module}: FAILED to enable"
            grep -E 'requires module|conflicting requests' /tmp/enable_${name}.log | head -3
            ret_val=1
        fi
    done
done

# Leave the system as we found it
dnf -y module reset $perl_streams &>/dev/null

t_CheckExitStatus $ret_val
