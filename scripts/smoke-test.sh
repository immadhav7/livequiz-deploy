#!/usr/bin/env bash
# Check health of dev and prod through the Ingress
set -euo pipefail
IP=$(terraform -chdir="$(dirname "$0")/../terraform" output -raw public_ip)

for env in dev prod; do
  printf "%-5s health: " "$env"
  curl -s -m 10 -H "Host: $env.livequiz.local" "http://$IP/actuator/health" || printf "no response"
  echo
done
