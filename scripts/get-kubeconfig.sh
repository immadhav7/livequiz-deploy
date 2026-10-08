#!/usr/bin/env bash
# Fetch the k3s kubeconfig from the Terraform-created server and point it at the server's public IP
set -euo pipefail

cd "$(dirname "$0")/../terraform"
IP=$(terraform output -raw public_ip)
KEY="$HOME/.ssh/livequiz-ec2"

# AWS can hand out an IP that was used before; forget any old host key for it
ssh-keygen -R "$IP" > /dev/null 2>&1 || true

mkdir -p "$HOME/.kube"
ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$KEY" "ubuntu@$IP" \
  "cloud-init status --wait > /dev/null; cat /etc/rancher/k3s/k3s.yaml" \
  | sed "s/127.0.0.1/$IP/" > "$HOME/.kube/livequiz-config"

chmod 600 "$HOME/.kube/livequiz-config"
echo "Kubeconfig written for $IP"
