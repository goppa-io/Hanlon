#!/bin/bash

./cli/hanlon tag add -n 'serialnumber' -f serialnumber

MODEL_UUID=$(./cli/hanlon model add -t debian_wheezy -l debian-jessie -i TikgPUUjKJ4sG4Xcxt0le -o debian.yml | awk 'FNR == 6 {print $3}')

./cli/hanlon policy add -p linux_deploy -l Core -m 2CHD2ud1tc7LWTUi2WqB6a -b none -t MXQ42100L6 -e true
