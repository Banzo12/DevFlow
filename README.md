# DevFlow

A containerized Node.js service with a full CI/CD pipeline that automatically builds, publishes, and deploys to AWS EC2 on every push to `main`.

This is a learning project that demonstrates an end-to-end DevOps workflow: containerization with Docker, image distribution via Docker Hub, automated builds with GitHub Actions, and zero-touch deployment to a Linux server in AWS.

---

## Architecture

```
Developer laptop
       │
       │  git push
       ▼
GitHub (this repo)  ─────────────────────────────────┐
       │                                             │
       │  triggers                                   │
       ▼                                             │
GitHub Actions runner (ephemeral Ubuntu VM)          │
       │                                             │
       │  1. Checkout repo                           │
       │  2. Set up Docker Buildx                    │
       │  3. Log in to Docker Hub (encrypted secret) │
       │  4. docker build (multi-layer cache)        │
       │  5. docker push                             │
       ▼                                             │
Docker Hub  ◄────  banzo12/devflow:latest            │
       │           banzo12/devflow:<commit-sha>      │
       │                                             │
       │  pulled by deploy job                       │
       ▼                                             │
Second runner (deploy job)                           │
       │                                             │
       │  SSH (encrypted private key in secret)      │
       ▼                                             │
AWS EC2 (Ubuntu 22.04 LTS, t3.micro, eu-north-1)     │
       │                                             │
       │  docker pull / stop / rm / run              │
       ▼                                             │
devflow-app container  (port 3000, --restart unless-stopped)
       │                                             │
       │  serves                                     │
       ▼                                             ▼
http://<elastic-ip>:3000  ──►  {"message":"DevFlow is live!", ...}
```

Every push to `main` reproduces this entire flow in approximately 75 seconds with zero human intervention.

---

## Tech stack

- **Application:** Node.js 18 (Express)
- **Container runtime:** Docker
- **Base image:** `node:18-alpine` (small, security-friendly)
- **Image registry:** Docker Hub (public)
- **Cloud:** AWS EC2 (t3.micro), Elastic IP for stable addressing
- **CI/CD:** GitHub Actions
- **Deploy mechanism:** SSH from runner via `appleboy/ssh-action`

---

## Endpoints

| Path | Response |
|---|---|
| `GET /` | `{"message":"DevFlow is live!","environment":"...","version":"..."}` |
| `GET /health` | `{"status":"healthy"}` — used by load balancers / orchestrators for liveness checks |

---

## CI/CD pipeline (`.github/workflows/ci.yml`)

Two-job workflow triggered on push to `main`:

1. **`build-and-push`** — Sets up Buildx, logs in to Docker Hub using encrypted secrets, builds the image with both `latest` and commit-SHA tags, and pushes to `banzo12/devflow`.
2. **`deploy`** — Depends on `build-and-push`. SSHes into the EC2 host using a private key stored as a GitHub secret, pulls the latest image, stops/removes the old container, and starts a new one with `--restart unless-stopped`. Includes a `curl` smoke test so the job fails if the new container doesn't respond.

### Secrets required

| Secret | Purpose |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub account name |
| `DOCKERHUB_TOKEN` | Docker Hub access token (read+write+delete) |
| `EC2_HOST` | Public IP / DNS of the deployment target |
| `EC2_SSH_KEY` | Full PEM contents of the private SSH key for the EC2 host |

---

## Local development

```bash
# Build the image
docker build -t devflow:dev .

# Run the container
docker run -d -p 3000:3000 --name devflow-dev devflow:dev

# Hit it
curl http://localhost:3000
curl http://localhost:3000/health

# Tear down
docker stop devflow-dev && docker rm devflow-dev
```

---

## Deploying changes

```bash
# Make a code change
git add .
git commit -m "feat: your change"
git push

# Watch the workflow run at:
# https://github.com/Banzo12/DevFlow/actions
```

The change is live on the EC2 host approximately 60–90 seconds after the push completes.

---

## Skills demonstrated

- Container engineering: multi-layer Dockerfile with build-cache awareness, `.dockerignore` hygiene
- Image distribution: Docker Hub with scoped access tokens (no plaintext credentials)
- Cloud provisioning: EC2 launch, security group inbound rules, Elastic IP allocation
- Linux administration: SSH key-based authentication, Docker daemon configuration, user/group permissions
- CI/CD: GitHub Actions workflows, encrypted secrets, job dependencies (`needs:`)
- Deployment automation: SSH from CI runner, idempotent deploy scripts, smoke testing
- Operational hygiene: secret rotation after a real key leak (early in the project history), `.gitignore` discipline

---

## Roadmap

Planned future enhancements (not yet implemented):

- **Phase 4 polish:** real Jest/Supertest test suite, multi-stage Dockerfile for smaller images, non-root container user, deploy notifications (Slack/email), commit-SHA-based versioning
- **Phase 5 hardening:** custom domain + Let's Encrypt TLS, AWS Application Load Balancer, CloudWatch logging
- **Phase 6 IaC:** rebuild the AWS infrastructure from Terraform instead of console clicks
- **Phase 7 orchestration:** migrate to Kubernetes (EKS) with Helm charts
- **Phase 8 observability:** Prometheus + Grafana metrics, structured logs to CloudWatch, alerting

---

## Author

Banele Banzo — `github.com/Banzo12`

Built as a self-directed DevOps learning project.
