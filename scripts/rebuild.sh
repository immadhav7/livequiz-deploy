#!/usr/bin/env bash
# Rebuild the whole LiveQuiz environment from Git:
# server (Terraform) -> k3s -> ArgoCD -> namespaces + DB secrets -> dev/prod applications
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF="$ROOT/terraform"
export KUBECONFIG="$HOME/.kube/livequiz-config"

echo "==> 1/6 Updating the firewall IP in terraform.tfvars"
MYIP=$(curl -s https://checkip.amazonaws.com | tr -d '[:space:]')
case "$MYIP" in
  *:*|"") echo "Could not get an IPv4 address (got: '$MYIP'). Aborting."; exit 1 ;;
esac
INSTANCE_TYPE=$(grep -E '^instance_type' "$TF/terraform.tfvars" 2>/dev/null | cut -d'"' -f2 || true)
INSTANCE_TYPE=${INSTANCE_TYPE:-m7i-flex.large}
printf 'my_ip_cidr = "%s/32"\ninstance_type = "%s"\n' "$MYIP" "$INSTANCE_TYPE" > "$TF/terraform.tfvars"
echo "    my IP: $MYIP, instance type: $INSTANCE_TYPE"

echo "==> 2/6 Creating the server with Terraform (review the plan, then type yes)"
terraform -chdir="$TF" apply

echo "==> 3/6 Waiting for k3s and fetching the kubeconfig"
for i in $(seq 1 20); do
  if "$ROOT/scripts/get-kubeconfig.sh"; then break; fi
  echo "    server not ready yet, retrying in 15s ($i/20)"
  sleep 15
done
kubectl wait --for=condition=Ready node --all --timeout=180s

echo "==> 4/6 Installing ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "==> 5/6 Creating namespaces and database secrets (random passwords, never in Git)"
for ns in livequiz-dev livequiz-prod; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
  if ! kubectl -n "$ns" get secret livequiz-db > /dev/null 2>&1; then
    kubectl -n "$ns" create secret generic livequiz-db \
      --from-literal=mysql-root-password="$(openssl rand -hex 16)" \
      --from-literal=mysql-password="$(openssl rand -hex 16)"
  fi
done

echo "==> 6/6 Registering the ArgoCD applications"
kubectl apply -f "$ROOT/argocd/app-dev.yaml" -f "$ROOT/argocd/app-prod.yaml"
kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy \
  application/livequiz-dev --timeout=420s || echo "    dev is not Healthy yet; check the ArgoCD UI"

echo
echo "Done. Server IP: $(terraform -chdir="$TF" output -raw public_ip)"
echo "Next:"
echo "  export KUBECONFIG=\$HOME/.kube/livequiz-config"
echo "  $ROOT/scripts/argocd-ui.sh      (run in its own tab; then sync livequiz-prod in the UI)"
echo "  $ROOT/scripts/smoke-test.sh"
echo "Remember: $ROOT/scripts/teardown.sh when you stop for the day."
