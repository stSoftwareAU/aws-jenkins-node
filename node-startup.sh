#!/bin/bash
# This script is auto pulled and run when a node is started for jenkins. 

set -ex
echo "starting to run node-startup.sh..."
sudo systemctl start docker.service
