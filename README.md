# FinTrack Infrastructure

GitOps infrastructure for [FinTrack] - a personal finance tracker deployed on AWS EKS with a complete DevOps pipeline - Terraform-provisioned infrastructure, GitOps delivery via ArgoCD, zero-downtime rolling updates, horizontal pod autoscaling, and end-to-end observability using Prometheus, Alertmanager, and Grafana.

## Architecture Overview

Architecture Diagram

## Stack

| Layer         | Technology                                       |
| ------------- | ------------------------------------------------ |
| Cloud         | AWS (EKS, RDS, S3, ECR, IAM, IRSA)               |
| IaC           | Terraform (modular, remote state)                |
| Orchestration | Kubernetes 1.31 on EKS (3-node, t3.small)        |
| CI            | GitHub Actions with OIDC (no stored credentials) |
| CD            | ArgoCD (pull-based GitOps)                       |
| Secrets       | Bitnami Sealed Secrets                           |
| TLS           | AWS ACM                                          |
| Ingress       | nginx-ingress + Classic ELB                      |
| Monitoring    | Prometheus + Grafana + Alertmanager              |
| DNS           | Route53                                          |
| DB Migrations | Prisma Migrate via Kubernetes Job in CI          |

## Repository Structure

```
fintrack-infrastructure/   - this repo - Terraform modules
fintrack-gitops/           - Kubernetes manifests (ArgoCD watches this)
fintrack-frontend/         - React + Vite application
fintrack-backend/          - Node.js + Fastify + Prisma API
```

| Repo                                                             | Description                               |
| ---------------------------------------------------------------- | ----------------------------------------- |
| [fintrack-frontend](https://github.com/qezman/fintrack-frontend) | React + Vite frontend                     |
| [fintrack-backend](https://github.com/qezman/fintrack-backend)   | Fastify + Prisma + PostgreSQL API         |
| [fintrack-gitops](https://github.com/qezman/fintrack-gitops)     | GitOps manifests - ArgoCD source of truth |

## Key Engineering Decisions

- **GitOps over push-based CD** - ArgoCD pulls from Git rather than CI pushing to the cluster. Deployments are auditable, reversible, and drift is auto-corrected.
- **OIDC over stored credentials** - GitHub Actions assumes an IAM role via OpenID Connect. No AWS keys stored anywhere.
- **IRSA over instance profiles** - The backend pod assumes a scoped IAM role via Kubernetes service account annotation. S3 access is pod-specific, not node-wide.
- **Sealed Secrets over plaintext** - Secrets are encrypted with the cluster's public key before being committed to Git. The private key never leaves the cluster.
- **Modular Terraform** - Each infrastructure component (VPC, EKS, RDS, S3, IAM) is an independent reusable module. The environment layer wires them together.
- **Rolling updates over recreate** - `maxSurge: 1 / maxUnavailable: 0` ensures new pods are healthy before old ones are terminated. Zero downtime on every deploy.
- **HPA over fixed replicas** - Backend scales from 2 to 5 replicas automatically based on CPU (70%) and memory (80%) utilization.
- **Kubernetes Job for migrations** - Prisma migrations run inside the cluster as a Job on every CI push, ensuring DB schema is always in sync before the new image is deployed.
- **Alertmanager routing** - Watchdog heartbeat routed to null receiver. All real alerts routed to email with **send_resolved: true** for automatic resolution notifications.

## Infrastructure Components

| Component | Details                                                                    |
| --------- | -------------------------------------------------------------------------- |
| VPC       | 10.0.0.0/16, 2 public + 2 private subnets across us-east-1a and us-east-1b |
| EKS       | Kubernetes 1.31, t3.small nodes, managed node group                        |
| RDS       | PostgreSQL 16, db.t3.micro, private subnets only                           |
| S3        | Private bucket for receipt uploads, presigned URL access                   |
| ECR       | Private image registry, 10-image lifecycle policy                          |

## Remote State

Terraform state is stored remotely in S3 with DynamoDB locking:

```
S3 Bucket:      terraform-fintrack-state-203637463799
DynamoDB Table: fintrack-terraform-locks
Region:         us-east-1
```

## CI/CD Pipeline

```
Push to main
  → Build Docker image
  → Push to ECR
  → Run Prisma migration Job inside cluster (VPC access to RDS)
  → Wait for migration to complete
  → Update image tag in fintrack-gitops
  → ArgoCD detects change → rolling update deploy
```

## Observability

- **Prometheus** - scrapes cluster and app metrics via kube-prometheus-stack
- **Alertmanager** - routes alerts to email; null receiver for Watchdog heartbeat
- **Grafana** - dashboards for cluster health, pod resources, and alert status
- **Custom PrometheusRule** - alert rules defined as code, version-controlled in Git

## Remote State

Terraform state is stored remotely in S3 with DynamoDB locking:

## Getting Started

### Prerequisites

- AWS CLI configured with appropriate IAM permissions
- Terraform >= 1.5.0
- kubectl
- Helm >= 3.0
- kubeseal

### Phase 1 - Infrastructure

```bash
cd environments/dev

> **Note (WSL users):** If Terraform fails with TLS handshake timeout errors, run:
> `export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")`
> before applying.

# Phase 1: AWS infrastructure only
terraform apply \
  -target=module.vpc \
  -target=module.eks \
  -target=module.rds \
  -target=module.s3 \
  -target=module.iam \
  -auto-approve

# Reconnect kubectl
aws eks update-kubeconfig --name fintrack-dev --region us-east-1

# Phase 2: Cluster bootstrap (ArgoCD, nginx-ingress, cert-manager, sealed-secrets)
terraform apply -auto-approve
```

### Phase 2 - GitOps

```bash
# Grant cluster access
aws eks create-access-entry \
  --cluster-name fintrack-dev \
  --principal-arn arn:aws:iam::203637463799:user/eks-project-user \
  --region us-east-1 2>/dev/null || true

aws eks associate-access-policy \
  --cluster-name fintrack-dev \
  --principal-arn arn:aws:iam::203637463799:user/eks-project-user \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region us-east-1

# Apply ArgoCD application manifests
kubectl apply -f fintrack-gitops/apps/frontend.yaml
kubectl apply -f fintrack-gitops/apps/backend.yaml
kubectl apply -f fintrack-gitops/apps/cluster.yaml
```

### Phase 3 - Secrets

```bash
# Reseal secrets for new cluster
cat > /tmp/backend-secret.yaml << 'SECRETEOF'
apiVersion: v1
kind: Secret
metadata:
  name: fintrack-backend-secrets
  namespace: fintrack
type: Opaque
stringData:
  DATABASE_URL: "postgresql://fintrack_admin:<password>@<rds-endpoint>:5432/fintrack"
  JWT_SECRET: "<your-jwt-secret>"
SECRETEOF

kubeseal \
  --controller-name sealed-secrets \
  --controller-namespace sealed-secrets \
  --format yaml \
  < /tmp/backend-secret.yaml \
  > fintrack-gitops/manifests/backend/sealedsecret.yaml

rm /tmp/backend-secret.yaml
cd fintrack-gitops && git add manifests/backend/sealedsecret.yaml
git commit && git push
```

### Phase 4 - Database

```bash
# Migrations run automatically via CI on every push to main.
# To run manually:
kubectl run prisma-migrate \
  --image=203637463799.dkr.ecr.us-east-1.amazonaws.com/fintrack-backend:latest \
  --restart=Never \
  --namespace=fintrack \
  --overrides='{"spec":{"containers":[{"name":"prisma-migrate","image":"203637463799.dkr.ecr.us-east-1.amazonaws.com/fintrack-backend:latest","command":["npx","prisma","migrate","deploy"],"envFrom":[{"secretRef":{"name":"fintrack-backend-secrets"}}]}],"serviceAccountName":"fintrack-backend"}}'
```

## Monitoring

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9091:9090

# Access Alertmanager
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
```

- Grafana: `http://localhost:3000` - username: `admin` | password: `fintrack-grafana-2025` - Prometheus: `http://localhost:9091` - Alertmanager: `http://localhost:9093`

> Destroy when not in use: `terraform destroy -auto-approve`

## NB

-target: Used only for the Phase 1 -> Phase 2 bootstrap split, where the Kubernetes provider requires the EKS cluster to exist first. Not used for routine changes — regular terraform apply is preferred once the cluster is bootstrapped.

## Documentation

Full setup guide, architecture decisions, and redeployment walkthrough:

[FinTrack Platform Documentation](https://polarized-boater-990.notion.site/FinTrack-EKS-Platform-38d604d0a68980168e51cf384b92a454)

## Author

**Kazeem**
