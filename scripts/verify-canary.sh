#!/usr/bin/env bash
set -euo pipefail

NS="${NAMESPACE:-pipeline-safety}"
REQUESTS="${REQUESTS:-100}"
MAX_ERROR_PERCENT="${MAX_ERROR_PERCENT:-2}"

kubectl -n "$NS" rollout status deployment/app-v1 --timeout=120s
kubectl -n "$NS" rollout status deployment/app-v2-canary --timeout=120s

kubectl -n "$NS" delete pod canary-check --ignore-not-found=true >/dev/null 2>&1 || true

kubectl -n "$NS" run canary-check \
  --image=curlimages/curl:8.10.1 \
  --restart=Never --command -- sh -c "
    i=0
    failures=0
    while [ \$i -lt $REQUESTS ]; do
      code=\$(curl -s -o /dev/null -w '%{http_code}' \
        --max-time 3 http://app-canary/api || echo 000)
      if [ \"\$code\" != '200' ]; then
        failures=\$((failures + 1))
      fi
      i=\$((i + 1))
    done
    echo \"requests=$REQUESTS failures=\$failures\"
    awk -v f=\$failures -v n=$REQUESTS -v max=$MAX_ERROR_PERCENT \
      'BEGIN { rate=f/n*100; printf \"error_percent=%.2f%%\\n\", rate; if (rate > max) exit 1 }'
  "

# Wait for the test pod to reach either Succeeded or Failed.
PHASE=""
for i in $(seq 1 90); do
  PHASE="$(kubectl -n "$NS" get pod canary-check \
    -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  if [[ "$PHASE" == "Succeeded" || "$PHASE" == "Failed" ]]; then
    break
  fi
  sleep 2
done

kubectl -n "$NS" logs canary-check || true

SELECTOR="$(kubectl -n "$NS" get service app-stable \
  -o jsonpath='{.spec.selector.version}')"

if [[ "$SELECTOR" != "v1" ]]; then
  echo "ERROR: stable Service selector is $SELECTOR, expected v1"
  exit 2
fi

kubectl -n "$NS" delete pod canary-check --ignore-not-found=true >/dev/null

if [[ "$PHASE" == "Failed" ]]; then
  echo "CANARY REJECTED: error threshold exceeded or test command failed."
  echo "Stable v1 remains selected."
  exit 1
fi

if [[ "$PHASE" != "Succeeded" ]]; then
  echo "ERROR: canary test pod did not finish; phase=$PHASE"
  exit 2
fi

echo "CANARY PASSED: measured error rate was within threshold."
