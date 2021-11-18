#!/bin/bash
# This script is auto pulled and run when a node is started for jenkins. 

set -ex
echo "starting to run node-startup.sh..."

sudo systemctl restart docker.service
sudo systemctl restart awslogsd.service

## NOTE ##
## in the file '/etc/cloud/cloud.cfg' when property 'ssh_pwauth' is set to 'false', on system reboot 'PasswordAuthentication' automatically sets to 'no'.
sed -i "/^[^#]*PasswordAuthentication/c\PasswordAuthentication yes" /etc/ssh/sshd_config
sudo systemctl restart sshd

set +x
echo "setup authorized_keys"
secret_JS=$(aws secretsmanager get-secret-value --secret-id "common_secrets" --region ap-southeast-2)
authorized_keys=$(jq -r '.DevOps_authorized_keys' <<< "${key_pairs_JS}")
echo ${authorized_keys} > /home/jenkins/.ssh/authorized_keys
chmod 600 /home/jenkins/.ssh/*

echo "finished running node-startup.sh"
