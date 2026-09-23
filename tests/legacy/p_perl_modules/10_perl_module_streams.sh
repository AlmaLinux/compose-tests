#!/bin/bash
# Same check, but against every perl stream rather than only the default one.
# A split batch can leave the default stream's context resolvable while the
# other three are broken, so each module is checked once per perl stream.

t_SkipReleaseLessThan 8 'no modularity'

t_Log "Running $0 - enabling every perl module stream against every perl stream"

perl_modules="perl-DBI:1.641 perl-YAML:1.24 perl-FCGI:0.78 perl-IO-Socket-SSL:2.066
              perl-App-cpanminus:1.7044 perl-DBD-MySQL:4.046 perl-DBD-Pg:3.7
              perl-DBD-SQLite:1.58 perl-libwww-perl:6.34"
perl_module_names="perl-DBI perl-YAML perl-FCGI perl-IO-Socket-SSL perl-App-cpanminus
                   perl-DBD-MySQL perl-DBD-Pg perl-DBD-SQLite perl-libwww-perl"
perl_streams=$(dnf -q module list perl 2>/dev/null | awk '$1=="perl" {print $2}')

ret_val=0
for stream in $perl_streams; do
    dnf -y module reset perl $perl_module_names &>/dev/null
    if ! dnf -y module enable "perl:${stream}" &>/tmp/enable_perl_${stream}.log; then
        t_Log "  perl:${stream}: FAILED to enable"
        ret_val=1
        continue
    fi
    for module in $perl_modules; do
        name=${module%%:*}
        dnf -q module info "$module" &>/dev/null || continue
        dnf -y module reset $perl_module_names &>/dev/null
        if dnf -y module enable "$module" &>/tmp/enable_${name}.log; then
            t_Log "  perl:${stream} + ${module}: OK"
        else
            t_Log "  perl:${stream} + ${module}: FAILED to enable"
            grep -E 'requires module|conflicting requests' /tmp/enable_${name}.log | head -3
            ret_val=1
        fi
    done
done

dnf -y module reset perl $perl_module_names &>/dev/null

t_CheckExitStatus $ret_val
