# this file defines the list of classes to be loaded under model
# here all the load files are maintained in the order of dependency
#
# This can be replace if we find a more meaningful method of loading classes

# level 1
require 'model/base'
require 'model/boot_local'
require 'model/discover_only'

# level 2
require 'model/redhat'
require 'model/ubuntu'
require 'model/debian'
require 'model/opensuse_12'
require 'model/sles_11'
require 'model/vmware_esxi'
require 'model/xenserver'
require 'model/windows'
require 'model/coreos'
require 'model/in_memory'

# level 3 - redhat
require 'model/redhat_6'
require 'model/redhat_7'

# level 3 - centos
require 'model/centos_6'

# leval 3 - oracle
require 'model/oraclelinux_6'

# level 3 - ubuntu
require 'model/ubuntu_oneiric'
require 'model/ubuntu_precise'
require 'model/ubuntu_precise_ip_pool'
require 'model/ubuntu_quantal'
require 'model/ubuntu_raring'
require 'model/ubuntu_trusty'
require 'model/ubuntu_vivid'
require 'model/ubuntu_xenial'

# level 3 - debian
require 'model/debian_wheezy'

# level 3 - vmware
require 'model/vmware_esxi_5'
require 'model/vmware_esxi_5_dhcp'

# level 3 - xenserver
require 'model/xenserver_boston'
require 'model/xenserver_tampa'

# level 3 - windows
require 'model/windows_2012_r2'

# level 3 - coreos
require 'model/coreos_stable'
require 'model/coreos_in_memory'

# level 3 - rancheros
require 'model/rancheros_in_memory'

# level 3 - linuxkit
require 'model/linuxkit_in_memory'
