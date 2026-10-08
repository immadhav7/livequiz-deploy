#!/usr/bin/env bash
# Destroy the server and everything Terraform created, then check nothing is left running
set -euo pipefail

cd "$(dirname "$0")/../terraform"
terraform destroy

echo
echo "Servers still present (should print nothing):"
aws ec2 describe-instances --region ap-south-2 \
  --filters Name=tag:Project,Values=livequiz Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text
