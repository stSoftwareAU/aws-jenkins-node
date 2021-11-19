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
# setup ssh key
echo "setup ssh key"
mkdir -p /home/jenkins/.ssh
#retry 5 times to see if we can get the permission, if retry doesn't work, we still can shutdown the instance if no permission
for i in 1 2 3 4 5; do aws secretsmanager list-secrets --region ap-southeast-2 && break || sleep 15; done

secret_JS=$(aws secretsmanager get-secret-value --secret-id "common_secrets" --region ap-southeast-2)
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.github_id_rsa' <<< "${key_pairs_JS}")
echo "${private_key_64}" | base64 -i --decode > /home/jenkins/.ssh/id_rsa
public_key_64=$(jq -r '.github_id_rsa_pub' <<< "${key_pairs_JS}")
echo "${public_key_64}" | base64 -i --decode > /home/jenkins/.ssh/id_rsa.pub

authorized_keys=$(jq -r '.DevOps_authorized_keys' <<< "${key_pairs_JS}")
echo ${authorized_keys} > /home/jenkins/.ssh/authorized_keys

known_hosts=$(jq -r '.github_known_hosts' <<< "${key_pairs_JS}")
echo "${known_hosts}" >> /home/jenkins/.ssh/known_hosts

set -x
chown -R jenkins:docker /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/*

echo "finished running node-startup.sh"
