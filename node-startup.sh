#!/bin/bash
# This script is auto pulled and run when a node is started for jenkins. 

set -ex
echo "starting to run node-startup.sh..."

sudo systemctl start docker.service
sudo systemctl start awslogsd.service

## NOTE ##
## in the file '/etc/cloud/cloud.cfg' when property 'ssh_pwauth' is set to 'false', on system reboot 'PasswordAuthentication' automatically sets to 'no'.
sed -i "/^[^#]*PasswordAuthentication/c\PasswordAuthentication yes" /etc/ssh/sshd_config
sudo systemctl start sshd

echo "finished running node-startup.sh"