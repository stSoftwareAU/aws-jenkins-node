#!/bin/bash
set -e

sed -i -e 's/#root:.*/root: support@stsoftware.com.au/g' /etc/aliases

set +e
adduser jenkins
set -e
mkdir -p /home/jenkins
usermod --home /home/jenkins jenkins
runuser -l jenkins /usr/bin/bash -c "/usr/bin/aws configure set default.region ap-southeast-2"
cp -a /home/ec2-user/.ssh /home/jenkins/
chown -R jenkins /home/jenkins

amazon-linux-extras install docker
usermod --gid docker jenkins
chown -R jenkins:docker /home/jenkins

yum update –y
amazon-linux-extras enable corretto8
yum install -y awslogs ntp java-1.8.0-amazon-corretto git jq
#install postgres 11.6.1
yum install -y https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-6-x86_64/postgresql11-libs-11.6-1PGDG.rhel6.x86_64.rpm
yum install -y https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-6-x86_64/postgresql11-11.6-1PGDG.rhel6.x86_64.rpm

#install apache ant
mkdir -p /tmp
cd /tmp
wget http://apache.mirror.serversaustralia.com.au//ant/binaries/apache-ant-1.9.15-bin.tar.gz
tar -xzf apache-ant-1.9.15-bin.tar.gz
rm -rf /tmp/apache-ant
ln -s apache-ant-1.9.15 apache-ant

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
#chkconfig ntpd on
systemctl enable ntpd.service

# Set up logs
sed --in-place -E "s/( *region *=)(.*)/\1 ap-southeast-2/" /etc/awslogs/awscli.conf

echo "[general]" > /etc/awslogs/awslogs.conf
echo "state_file = /var/lib/awslogs/agent-state" >> /etc/awslogs/awslogs.conf
echo "use_gzip_http_content_encoding=true" >> /etc/awslogs/awslogs.conf

echo "" >> /etc/awslogs/awslogs.conf
echo "[/var/log/messages]" >> /etc/awslogs/awslogs.conf
echo "log_group_name = tp-php_/var/log/messages" >> /etc/awslogs/awslogs.conf
echo "datetime_format = %b %d %H:%M:%S" >> /etc/awslogs/awslogs.conf
echo "file = /var/log/messages" >> /etc/awslogs/awslogs.conf
echo "log_stream_name = {instance_id}" >> /etc/awslogs/awslogs.conf

# setup ssh key
mkdir -p /home/jenkins/.ssh
secret_JS=$(aws secretsmanager get-secret-value --secret-id "common_secrets" --region ap-southeast-2)
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.github_id_rsa' <<< "${key_pairs_JS}")
echo "${private_key_64}" | base64 -i --decode | zcat > /home/jenkins/.ssh/id_rsa

known_hosts=$(jq -r '.github_known_hosts' <<< "${key_pairs_JS}")
echo "${known_hosts}" >> /home/jenkins/.ssh/known_hosts

chown -R jenkins:docker /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/*

systemctl restart awslogsd.service
systemctl start docker.service
