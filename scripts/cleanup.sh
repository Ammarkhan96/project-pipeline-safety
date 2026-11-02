#!/usr/bin/env bash
set -euo pipefail

kubectl delete namespace pipeline-safety --ignore-not-found=true

echo "Project namespace deleted."
echo "To delete only this project's kind cluster:"
echo "kind delete cluster --name pipeline-safety"
