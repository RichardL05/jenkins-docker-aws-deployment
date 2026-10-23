#!/usr/bin/env bash
# Run as a Jenkins Freestyle "Execute shell" step on node label docker-slave.
set -eu

echo '=== Jenkins agent verification ==='
echo "NODE_NAME=${NODE_NAME:-not-set}"
echo 'Hostname:'
hostname
echo 'Linux account:'
whoami
echo 'Working directory:'
pwd
echo 'Docker CLI version:'
docker --version
echo 'Docker running containers:'
docker ps
echo '=== Agent and Docker checks succeeded ==='
