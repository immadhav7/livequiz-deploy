#!/usr/bin/env bash
# Open the ArgoCD UI at https://localhost:8081 (keep this terminal tab open)
set -euo pipefail
export KUBECONFIG="$HOME/.kube/livequiz-config"

echo "ArgoCD UI: https://localhost:8081   user: admin"
printf "Password:  "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
echo "Press Ctrl+C to stop the port-forward"
kubectl -n argocd port-forward svc/argocd-server 8081:443
