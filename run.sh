#!/bin/bash
set -e
sudo yum install -y java
#format and mount encrypted drive
#mv /home/ec2-user /root/
#mkfs -t ext4 /dev/sdb
#mount /dev/sdb /home
#mv /root/ec2-user /home/

#uuid=`file -Ls /dev/sdb | sed -n "s/^.*\(UUID=\S*\).*$/\1/p"`
#echo "${uuid}     /home   ext4    defaults,nofail        0       2" >> /etc/fstab
