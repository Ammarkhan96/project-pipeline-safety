# Project Details: Pipeline Safety Gate

A CI/CD project demonstrating how to reject a bad Kubernetes canary
release while keeping the stable application version selected.

## Tech Stack

- Python and Flask
- Docker
- Kubernetes and kind
- GitHub Actions
- Prometheus-compatible application metrics
- Bash automation

## Architecture

Git push / Pull Request
        |
        v
GitHub Actions
        |
        v
Unit tests + Docker build
        |
        v
Temporary Kubernetes cluster
        |
        +--------------------+
        |                    |
     Stable v1             Canary v2
     Healthy               ~20% HTTP 500
        |                    |
        |              100-request test
        |                    |
        |              Error rate > 2%
        |                    |
        |              Reject promotion
        +--------------------+
             Stable Service
             remains on v1

## Project Features

- Automated Flask unit tests.
- Docker image build.
- Kubernetes stable and canary deployments.
- HTTP health and readiness endpoints.
- HTTP request metrics at `/metrics`.
- Canary verification using HTTP response codes.
- CI/CD gate that fails when the canary exceeds the error threshold.
- Verification that the stable Service continues selecting v1.

## Prerequisites

Install Docker, kubectl, kind, Git and Python 3.

Check the installations:

```bash
docker --version
docker info
kubectl version --client
kind version
python3 --version
git --version
```

## Run Locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt

cd app
python -m unittest -v
cd ..

docker build -t pipeline-safety-demo:local app
chmod +x scripts/*.sh
./scripts/local-demo.sh
```

The local script creates a kind cluster named `pipeline-safety`
if one does not already exist, then deploys both releases.

## Verify the Canary

```bash
REQUESTS=100 MAX_ERROR_PERCENT=2 ./scripts/verify-canary.sh
```

The intentionally degraded v2 should exceed the 2% threshold.
The script should report a rejected canary and exit with code 1.

Verify the stable selector:

```bash
kubectl -n pipeline-safety get service app-stable \
  -o jsonpath='{.spec.selector.version}{"\n"}'
```

Expected output:

```text
v1
```

## GitHub Actions

The workflow is located at `.github/workflows/deploy.yml`.

It runs tests, builds the image, creates a temporary kind cluster,
deploys stable and canary releases, executes the error-rate gate,
and checks that the stable version remains selected.

A failed workflow at the canary gate is expected when the bad
release is correctly rejected. Failures in earlier stages are not
expected and should be investigated.

## Prometheus Metrics

The Flask application exposes counters at `/metrics`.
The configuration in `prometheus/prometheus.yml` describes scrape
targets, but a Prometheus server must be deployed and configured
before live dashboards or PromQL-based release decisions are available.

## Cleanup

```bash
./scripts/cleanup.sh
kind delete cluster --name pipeline-safety
```

Only delete the project-specific cluster, not unrelated clusters.

## Verification Checklist

- [ ] Unit tests pass.
- [ ] Docker image builds.
- [ ] Both Kubernetes deployments become ready.
- [ ] Stable API returns HTTP 200.
- [ ] Canary error rate exceeds 2%.
- [ ] Canary gate rejects the bad release.
- [ ] Stable Service selector remains v1.
- [ ] GitHub Actions reports the expected canary rejection.

## Resume Bullet

Built a GitHub Actions CI/CD safety gate that deploys stable and
canary releases to Kubernetes, measures HTTP error rates, blocks
unsafe release promotion, and verifies that the stable version
remains selected.
