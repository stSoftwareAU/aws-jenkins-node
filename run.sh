#!/bin/bash
set -e

sed -i -e 's/#root:.*/root: support@stsoftware.com.au/g' /etc/aliases

yum update –y
amazon-linux-extras enable corretto8
amazon-linux-extras install docker
yum install -y awslogs ntp java-1.8.0-amazon-corretto git

# install rake used for codepipeline
curl -O https://rubygems.org/rubygems/rubygems-3.0.3.tgz
tar zxf rubygems-3.0.3.tgz
cd rubygems-3.0.3
ruby setup.rb --no-format-executable
gem update
gem install rake

set +e
adduser jenkins
set -e
mkdir -p /home/jenkins
usermod --home /home/jenkins --gid docker jenkins
runuser -l jenkins /usr/bin/bash -c "/usr/bin/aws configure set default.region ap-southeast-2"
cp -a /home/ec2-user/.ssh /home/jenkins/
chown -R jenkins:docker /home/jenkins

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

systemctl restart awslogsd.service
systemctl start docker.service
