#!/bin/bash
# Author: Yuriy Kohut <ykohut@almalinux.org>

# OS major version and machine hardware name
crb='PowerTools'
if [ "x${centos_ver}" = "x9" -o "x${centos_ver}" = "x10" ]; then
    crb='CRB'
fi

t_Log "Verify that the installation works"

systemctl enable --now osbuild-composer.socket

systemctl restart osbuild-composer

composer-cli status show || t_CheckExitStatus $?

if [ "x${pungi_repository}" = "xtrue" ]; then
    t_Log "Running $0 - osbuild: Change 'baseurl' for native BaseOS and AppStream repositories into pungi one"
    latest_result="latest_result"
    json_file=almalinux-${release_ver}.json
    if [ "$centos_ver" = "$release_ver" ]; then
        # Assume Kitten
        latest_result="latest_result_almalinux-kitten"
        json_file=almalinux-kitten-${release_ver}.json
    fi
    os_repo_json="/usr/share/osbuild-composer/repositories/${json_file}"
    test -e ${os_repo_json}.bak || cp -av ${os_repo_json} ${os_repo_json}.bak
    t_InstallPackageMinimal jq
    for repo_name in BaseOS AppStream; do
        name=${repo_name,,}
        baseurl="http://${arch}-pungi-${centos_ver}.almalinux.org/almalinux/${centos_ver}/${arch}/${latest_result}/compose/${repo_name}/${arch}/os/"
        cat ${os_repo_json} | jq --arg arch "${arch}" --arg baseurl "${baseurl}" --arg name "${name}" '(.'$arch'[] | select(.name == $name) | .baseurl) |= $baseurl' > ${os_repo_json}.new || t_CheckExitStatus $?
        mv -f ${os_repo_json}.new ${os_repo_json}
    done

    t_Log "Running $0 - osbuild: check if the new source was successfully added"
    composer-cli sources list || t_CheckExitStatus $?
else
    true
    t_CheckExitStatus $?
fi
