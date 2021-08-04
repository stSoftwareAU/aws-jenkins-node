#!/bin/bash
set -ex

function retry {
  local max_attempts=${ATTEMPTS-6} ##ATTEMPTS (default 6)
  local timeout=${TIMEOUT-1}       ##TIMEOUT in seconds (default 1.) doubles on each attempt
  local attempt=0
  local exitCode=0

  set +e
  while [[ $attempt < $max_attempts ]]
  do
    "$@" && { 
      exitCode=0
      break 
    }
    exitCode=$?

    if [[ $exitCode == 0 ]]
    then
      break
    fi

    echo "Failure! Retrying in $timeout.." 1>&2
    sleep $timeout
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
  done
  set -e

  if [[ $exitCode != 0 ]]
  then
    echo "You've failed me for the last time! ($@)" 1>&2
  fi

  return $exitCode
}


yum update -y
yum install -y awslogs

# Set up logs
sed --in-place -E "s/( *region *=)(.*)/\1 ap-southeast-2/" /etc/awslogs/awscli.conf

echo "[general]" > /etc/awslogs/awslogs.conf
echo "state_file = /var/lib/awslogs/agent-state" >> /etc/awslogs/awslogs.conf
echo "use_gzip_http_content_encoding=true" >> /etc/awslogs/awslogs.conf

echo "" >> /etc/awslogs/awslogs.conf
echo "[/var/log/messages]" >> /etc/awslogs/awslogs.conf
echo "log_group_name = messages_/var/log/messages" >> /etc/awslogs/awslogs.conf
echo "datetime_format = %b %d %H:%M:%S" >> /etc/awslogs/awslogs.conf
echo "file = /var/log/messages" >> /etc/awslogs/awslogs.conf
echo "log_stream_name = {instance_id}" >> /etc/awslogs/awslogs.conf

echo "" >> /etc/awslogs/awslogs.conf
echo "[/var/log/cloud-init-output.log]" >> /etc/awslogs/awslogs.conf
echo "log_group_name = cloud-init-output_/var/log/cloud-init-output.log" >> /etc/awslogs/awslogs.conf
echo "datetime_format = %b %d %H:%M:%S" >> /etc/awslogs/awslogs.conf
echo "file = /var/log/cloud-init-output.log" >> /etc/awslogs/awslogs.conf
echo "log_stream_name = {instance_id}" >> /etc/awslogs/awslogs.conf

systemctl restart awslogsd.service

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
systemctl start docker.service

yum install -y jq

# setup ssh key
mkdir -p /home/jenkins/.ssh
#retry 5 times to see if we can get the permission, if retry doesn't work, we still can shutdown the instance if no permission
for i in 1 2 3 4 5; do aws secretsmanager list-secrets --region ap-southeast-2 && break || sleep 15; done

secret_JS=$(aws secretsmanager get-secret-value --secret-id "common_secrets" --region ap-southeast-2)
key_pairs_JS=$(jq -r '.SecretString' <<< "${secret_JS}")
private_key_64=$(jq -r '.github_id_rsa' <<< "${key_pairs_JS}")
echo "${private_key_64}" | base64 -i --decode > /home/jenkins/.ssh/id_rsa
public_key_64=$(jq -r '.github_id_rsa_pub' <<< "${key_pairs_JS}")
echo "${public_key_64}" | base64 -i --decode > /home/jenkins/.ssh/id_rsa.pub

known_hosts=$(jq -r '.github_known_hosts' <<< "${key_pairs_JS}")
echo "${known_hosts}" >> /home/jenkins/.ssh/known_hosts

chown -R jenkins:docker /home/jenkins/.ssh
chmod 600 /home/jenkins/.ssh/*

yum install -y ntp maven git aspell

#install java8
#amazon-linux-extras enable corretto8
#yum install -y ntp maven git java-1.8.0-amazon-corretto-devel aspell

wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141-linux-x64.rpm --quiet

set +e
yum install -y jdk-8u141-linux-x64.rpm
set -e

#install Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm --quiet
set +e
yum install -y ./google-chrome-stable_current_*.rpm
set -e
google-chrome --version



#install firefox 
#sudo run-firefox.sh
#firefox --version


#install postgres 11.6.1
set +e
yum install -y https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-6-x86_64/postgresql11-libs-11.6-1PGDG.rhel6.x86_64.rpm
yum install -y https://download.postgresql.org/pub/repos/yum/11/redhat/rhel-6-x86_64/postgresql11-11.6-1PGDG.rhel6.x86_64.rpm
set -e

#install apache ant
antversion=1.9.16
mkdir -p /tmp
cd /tmp
wget https://downloads.apache.org//ant/binaries/apache-ant-${antversion}-bin.tar.gz --quiet
tar -xzf apache-ant-${antversion}-bin.tar.gz
rm -rf /tmp/apache-ant
ln -s apache-ant-${antversion} apache-ant
#install gwt-2.7.0
wget http://goo.gl/t7FQSn -O gwt-2.7.0.zip --quiet
unzip gwt-2.7.0.zip

su - jenkins -c 'git config --global user.email "service@stsoftware.com.au"'
su - jenkins -c 'git config --global user.name "AWS Jenkins"'

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
#chkconfig ntpd on
retry systemctl enable ntpd.service

#install ffmpeg
cd /usr/local/bin
mkdir ffmpeg
cd ffmpeg
for i in 1 2 3 4 5; do wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz && break || sleep 15; done
mkdir -p ffmpeg-release-amd64-static
tar xvf ffmpeg-release-amd64-static.tar.xz -C ffmpeg-release-amd64-static --strip-components=1
mv ffmpeg-release-amd64-static/ffmpeg .

ln -s /usr/local/bin/ffmpeg/ffmpeg /usr/bin/ffmpeg

#install c compiler for litmus test
yum groupinstall -y "Development Tools"

#install aspell language pack
wget https://ftp.gnu.org/gnu/aspell/dict/en/aspell6-en-2019.10.06-0.tar.bz2 --quiet
tar xjf aspell6-en-2019.10.06-0.tar.bz2
cd aspell6-en-2019.10.06-0/
./configure
make 
make install

set +e
aws configure list
set -e

#setup sftp
user=test
passw=Ujh76i9sa
userhome="/home/${user}"
userdata="${userhome}/data"
sshd_config='/etc/ssh/sshd_config'

groupadd sftp_users
adduser --shell /bin/bash --home /home/${user} ${user}

usermod -g sftp_users ${user}
echo "${user}:${passw}" | chpasswd

mkdir -p /data/${user}
chmod 701 /data
mkdir -p /data/${user}/upload
chown -R root:sftp_users /data/${user}
chown -R ${user}:sftp_users /data/${user}/upload

tab=$'\t'
cat <<EOF >>${sshd_config}
## START_SFTP_CONFIG ##
Match Group sftp_users
${tab}ChrootDirectory /data/%u
${tab}X11Forwarding no
${tab}PermitTunnel no
${tab}AllowAgentForwarding no
${tab}AllowTcpForwarding no
${tab}ForceCommand internal-sftp -d /upload
${tab}PasswordAuthentication yes
## END_SFTP_CONFIG ##
EOF

#start docker
#sudo systemctl start docker.service
#sudo systemctl start deluged

#wget https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
#yum install -y ./google-chrome-stable_current_*.rpm
#google-chrome --version

#install phantomjs
rm -f /usr/bin/phantomjs
rm -f /usr/local/phantomjs
mkdir -p /usr/local/phantomjs
wget -O- "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2" | tar -jx --directory /usr/local/phantomjs --strip-components 1 --quiet
ln -s /usr/local/phantomjs/bin/phantomjs /usr/bin/phantomjs

# moved to run-firefox.sh
#set -ex
#wget -O- "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" | tar -jx -C /usr/local/
#mkdir -p /etc/dnf/
#echo "exclude=firefox" >> /etc/dnf/dnf.conf
#ln -s /usr/local/firefox/firefox /usr/bin/firefox

#check jenkins git config should be set
set +e
cat /home/jenkins/.gitconfig
set -e

set +e
bash SetupAWS.sh
set -e

systemctl status docker

systemctl restart sshd
