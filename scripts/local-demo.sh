#!/usr/bin/env bash
set -euo pipefail

CLUSTER="pipeline-safety"
IMAGE="pipeline-safety-demo:local"

for tool in docker kubectl kind; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool"
    exit 1
  fi
done

docker info >/dev/null

docker build -t "$IMAGE" app

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

kind load docker-image "$IMAGE" --name "$CLUSTER"

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/stable-deployment.yaml
kubectl apply -f k8s/canary-deployment.yaml
kubectl apply -f k8s/stable-service.yaml
kubectl apply -f k8s/canary-service.yaml

kubectl -n pipeline-safety rollout status deployment/app-v1 --timeout=180s
kubectl -n pipeline-safety rollout status deployment/app-v2-canary --timeout=180s

echo
echo "===== DEPLOYMENTS, PODS AND SERVICES ====="
kubectl -n pipeline-safety get deployments,pods,services -o wide

echo
echo "===== STABLE SERVICE SELECTOR ====="
kubectl -n pipeline-safety get service app-stable \
  -o jsonpath='{.spec.selector}{"\n"}'

echo
echo "===== RUN CANARY GATE ====="
set +e
./scripts/verify-canary.sh
RESULT=$?
set -e

if [[ "$RESULT" -eq 1 ]]; then
  echo "Expected result: faulty canary rejected."
elif [[ "$RESULT" -eq 0 ]]; then
  echo "Canary passed this test run; investigate before treating it as rejected."
else
  echo "Unexpected verification problem; inspect the output above."
  exit "$RESULT"
fi
