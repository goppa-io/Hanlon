#!/bin/bash

function ii_up {
    for name in ${IPMI_HOSTS}; do
        eval local command="\"$1\""
        eval local node_args=\"\$IPMI_HOST_${name}\"
        eval local user_args=\"\$IPMI_USER_${name}\"
        eval local pass_args=\"\$IPMI_PASS_${name}\"
        ipmitool -I lanplus -U "${user_args}" -P "${pass_args}" -H "${node_args}" ${command}
        done
}
