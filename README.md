# Raspberry Pi k3s GitOps Platform

A clean, minimal GitOps platform for Raspberry Pi 4 (ARM64) using k3s, Argo CD, and comprehensive observability.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Raspberry Pi 4 (ARM64)                  │
│                   Ubuntu Server 22.04                      │
├─────────────────────────────────────────────────────────────┤
│                        k3s Cluster                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Argo CD   │  │ Sample App  │  │   Observability     │ │
│  │ (GitOps)    │  │ Frontend    │  │ - Prometheus        │ │
│  │             │  │ Backend     │  │ - Grafana           │ │
│  │             │  │ Database    │  │ - Loki              │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Ingress     │  │ Cert Mgr    │  │      Velero         │ │
│  │ Nginx       │  │ (Let's      │  │    (Backups)        │ │
│  │             │  │ Encrypt)    │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│              External USB Storage (8GB)                    │
│                  /mnt/usb-data                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Postgres    │  │ Prometheus  │  │ Loki + Velero       │ │
│  │ Data        │  │ TSDB        │  │ Backups             │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
k3s-argocd-rasp-pi/
├── infra/                    # Infrastructure as Code
│   ├── terraform/           # Terraform configurations
│   └── bootstrap/           # k3s installation scripts
├── gitops/                  # GitOps configurations
│   ├── bootstrap/           # Root application (apply once)
│   └── apps/               # Child applications (managed by Argo CD)
├── apps/                   # Sample application
│   ├── frontend/           # React SPA
│   ├── backend/            # Node.js API
│   ├── database/           # Postgres configuration
│   └── helm/               # Helm charts
└── .github/workflows/      # CI/CD pipeline
```

## Quick Start

### Prerequisites

- Raspberry Pi 4 with Ubuntu Server 22.04 (ARM64)
- External USB drive (8GB+) for persistent storage
- Domain name or DuckDNS subdomain for TLS certificates (optional)

### 1. Prepare the Pi

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/k3s-argocd-rasp-pi.git
cd k3s-argocd-rasp-pi

# Mount USB storage
make mount-usb
# Follow the instructions to mount your USB drive
```

### 2. Bootstrap the Platform

```bash
# One command to rule them all
make bootstrap
```

This will:

1. Install k3s with Pi-optimized settings
2. Install Argo CD using official manifests
3. Apply Terraform configurations for storage and namespaces
4. Deploy the root application that manages all other apps

### 3. Access Services

```bash
# Port forward to access services locally
make port-forward-grafana    # http://localhost:3000 (admin/admin)
make port-forward-argocd     # http://localhost:8080 (admin/get-password)

# Check status
make status
```

## GitOps Architecture

This platform uses the **App of Apps** pattern:

1. **Root Application** (`gitops/bootstrap/root-app.yaml`) - Applied once, manages everything
2. **Child Applications** (`gitops/apps/*.yaml`) - Automatically discovered and deployed

### Adding New Applications

Simply add a new YAML file to `gitops/apps/`:

```yaml
# gitops/apps/my-new-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.example.com
    chart: my-chart
    targetRevision: 1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Argo CD will automatically discover and deploy it!

## Included Applications

- **ingress-nginx**: Load balancer and ingress controller
- **cert-manager**: Automatic TLS certificates via Let's Encrypt
- **monitoring**: Prometheus, Grafana, AlertManager (kube-prometheus-stack)
- **logging**: Loki stack for log aggregation
- **sample-app**: Three-tier demo application (frontend, backend, database)

## Storage Configuration

The platform uses an external USB drive mounted at `/mnt/usb-data`:

```
/mnt/usb-data/
├── postgres/              # PostgreSQL data
├── prometheus/            # Prometheus TSDB
├── loki/                 # Loki log chunks
└── velero/               # Backup storage
```

## CI/CD Pipeline

GitHub Actions automatically:

1. **Builds** multi-arch Docker images (amd64/arm64)
2. **Pushes** to GitHub Container Registry
3. **Updates** GitOps manifests with new image tags
4. **Triggers** Argo CD sync for automatic deployment

### Setting Up CI/CD

1. Enable GitHub Container Registry in your repo settings
2. Update image repositories in `gitops/apps/sample-app.yaml`
3. Push to main branch - images build and deploy automatically!

## Common Tasks

```bash
make help                   # Show all available commands
make mount-usb              # Mount USB storage
make bootstrap              # Bootstrap entire platform
make port-forward-grafana   # Access Grafana dashboard
make port-forward-argocd    # Access Argo CD UI
make status                 # Show cluster status
make sync-apps              # Force sync all applications
make clean                  # Clean up everything
```

## Monitoring & Observability

- **Grafana**: Pre-configured dashboards for cluster and application metrics
- **Prometheus**: Metrics collection with 7-day retention
- **Loki**: Log aggregation with 7-day retention
- **AlertManager**: Alert routing (configure webhooks as needed)

Access Grafana at `http://localhost:3000` (admin/admin) after port-forwarding.

## Customization

### Update Configuration

1. **Modify values** in `gitops/apps/*.yaml`
2. **Commit and push** - Argo CD syncs automatically
3. **No kubectl needed** - everything is GitOps!

### Add Custom Applications

1. Create new YAML in `gitops/apps/`
2. Point to your Helm chart or manifests
3. Commit - Argo CD discovers and deploys

### Resource Limits

All components are configured with Pi-friendly resource limits:

- CPU: 50m-500m per component
- Memory: 64Mi-1Gi per component
- Storage: Conservative retention periods

## Troubleshooting

### Common Issues

1. **USB not mounting**: Check `/dev/sda1` exists and filesystem is ext4
2. **k3s not starting**: Ensure sufficient memory (4GB+ recommended)
3. **Applications not syncing**: Check Argo CD logs: `kubectl logs -n argocd deployment/argocd-server`
4. **Out of resources**: Reduce replica counts in app configurations

### Useful Commands

```bash
# Check Argo CD applications
kubectl get applications -n argocd

# Check all pods
kubectl get pods -A

# Check storage
kubectl get pv,pvc -A

# Argo CD logs
kubectl logs -n argocd deployment/argocd-server -f

# Force application sync
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{}}}'
```

## Security Considerations

- All services use least-privilege ServiceAccounts
- Network policies restrict database access
- TLS certificates via Let's Encrypt (when configured)
- Secrets managed via Kubernetes Secrets
- Multi-arch images scanned for vulnerabilities

## Resource Requirements

- **CPU**: Raspberry Pi 4 (4 cores recommended)
- **Memory**: 4GB+ RAM (8GB recommended)
- **Storage**: 32GB+ SD card + 8GB+ USB drive
- **Network**: Stable internet for image pulls and certificates

## What Makes This Different

✅ **Minimal glue code** - Uses official manifests and charts
✅ **True GitOps** - Everything managed through Git
✅ **Pi-optimized** - Resource limits tuned for ARM64
✅ **Production-ready** - Monitoring, logging, backups included
✅ **Easy to extend** - Just add YAML files to `gitops/apps/`
✅ **Clean architecture** - Separation of concerns, no manual kubectl

## Contributing

1. Fork the repository
2. Create feature branch
3. Test on Pi hardware
4. Submit pull request

## License

MIT License - see LICENSE file for details.

---

**Next Steps After Setup:**

1. Configure your domain in `gitops/apps/sample-app.yaml`
2. Set up DuckDNS or real domain for TLS certificates
3. Customize monitoring dashboards in Grafana
4. Add your own applications to `gitops/apps/`
