#!/bin/bash

./cli/hanlon tag add -n 'serialnumber' -f serialnumber

./cli/hanlon model add -t debian_wheezy -l debian-jessie -i TikgPUUjKJ4sG4Xcxt0le

./cli/hanlon model add -t debian_wheezy -l debian-jessie -i TikgPUUjKJ4sG4Xcxt0le -o debian.yml

./cli/hanlon policy add -p linux_deploy -l Core -m 2CHD2ud1tc7LWTUi2WqB6a -b none -t MXQ42100L6 -e true
