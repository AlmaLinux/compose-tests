#!/bin/bash
# A split module batch makes dnf print a "Modular dependency problems" block on
# every transaction while still exiting 0, so the exit status never shows it.

t_SkipReleaseLessThan 8 'no modularity'

t_Log "Running $0 - checking module metadata resolves cleanly"

dnf --assumeno install zip > /tmp/modular_deps.log 2>&1

if grep -q 'Modular dependency problems' /tmp/modular_deps.log; then
    t_Log "Unresolvable modules in repository metadata:"
    # the block is the header plus every blank/indented line that follows it
    awk '/Modular dependency problems/ {p=1; print; next}
         p && /^[[:space:]]*$/         {print; next}
         p && /^[[:space:]]/           {print; next}
         p                             {exit}' /tmp/modular_deps.log
    ret_val=1
else
    ret_val=0
fi

t_CheckExitStatus $ret_val
