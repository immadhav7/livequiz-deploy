#!/bin/bash
set -euxo pipefail

# Read this server's public IP from the instance metadata service (IMDSv2)
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

# Install k3s; the public IP is added to its certificate so kubectl works from the laptop
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san $PUBLIC_IP --write-kubeconfig-mode 644" sh -
