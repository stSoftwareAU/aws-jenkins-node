#!/bin/bash
# This script is auto pulled and run when a node is started for jenkins. 

set -e
sudo systemctl start docker.service
