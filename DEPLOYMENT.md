# Deployment Guide

## Quick Deployment Steps

### 1. Prerequisites

- Raspberry Pi 4 with Ubuntu Server 22.04 (ARM64)
- External USB drive (8GB+) formatted as ext4
- Git and basic tools installed

### 2. Clone and Setup

```bash
git clone https://github.com/YOUR_USERNAME/k3s-argocd-rasp-pi.git
cd k3s-argocd-rasp-pi

# Update repository URLs in the following files:
# - gitops/bootstrap/root-app.yaml
# - gitops/apps/sample-app.yaml
# - .github/workflows/ci-cd.yaml
```

### 3. Mount USB Storage

```bash
# Identify your USB device
sudo fdisk -l

# Format if needed (replace /dev/sda1 with your device)
sudo mkfs.ext4 /dev/sda1

# Mount and configure
sudo mkdir -p /mnt/usb-data
sudo mount /dev/sda1 /mnt/usb-data
sudo chown -R $USER:$USER /mnt/usb-data

# Add to fstab for persistence
echo "/dev/sda1 /mnt/usb-data ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### 4. Bootstrap Platform

```bash
make bootstrap
```

This single command:

1. Installs k3s with Pi-optimized settings
2. Installs Argo CD using official manifests
3. Applies Terraform for storage and namespaces
4. Deploys the root application

### 5. Verify Deployment

```bash
# Check status
make status

# Wait for all apps to sync (may take 5-10 minutes)
kubectl get applications -n argocd

# Access services
make port-forward-grafana    # http://localhost:3000
make port-forward-argocd     # http://localhost:8080
```

## What Gets Deployed

### Core Platform

- **k3s**: Lightweight Kubernetes
- **Argo CD**: GitOps controller
- **ingress-nginx**: Load balancer
- **cert-manager**: TLS certificates

### Observability Stack

- **Prometheus**: Metrics collection (7d retention)
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation (7d retention)
- **AlertManager**: Alert routing

### Sample Application

- **Frontend**: React SPA served by nginx
- **Backend**: Node.js API with /health and /metrics
- **Database**: PostgreSQL with persistent storage

### Storage Layout

```
/mnt/usb-data/
├── postgres/     # Database data
├── prometheus/   # Metrics storage
├── loki/        # Log storage
└── velero/      # Backup storage (future)
```

## Customization

### Update Application Images

1. Build and push your images to GHCR
2. Update image references in `gitops/apps/sample-app.yaml`
3. Commit and push - Argo CD syncs automatically

### Add New Applications

1. Create new YAML file in `gitops/apps/`
2. Point to your Helm chart or manifests
3. Commit - Argo CD discovers and deploys

### Modify Resource Limits

Edit the `values` section in each app YAML file in `gitops/apps/`

## Troubleshooting

### Common Issues

1. **Pods pending**: Check storage class exists and USB is mounted
2. **Out of memory**: Reduce resource requests in app configs
3. **Images not pulling**: Check GHCR permissions and image names
4. **Apps not syncing**: Check Argo CD logs and repo connectivity

### Useful Commands

```bash
# Force sync all apps
kubectl patch application root -n argocd --type merge -p '{"operation":{"sync":{}}}'

# Check specific app
kubectl describe application <app-name> -n argocd

# View logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n <namespace> deployment/<deployment-name>

# Check storage
kubectl get pv,pvc -A
df -h /mnt/usb-data
```

## Resource Usage

Typical resource consumption on Pi 4 (4GB):

- **k3s system**: ~500MB RAM
- **Argo CD**: ~200MB RAM
- **Monitoring stack**: ~800MB RAM
- **Sample app**: ~300MB RAM
- **Total**: ~1.8GB RAM (leaves 2GB+ free)

## Security Notes

- All components run as non-root users
- Network policies restrict database access
- TLS certificates auto-renewed via cert-manager
- Secrets managed via Kubernetes native secrets
- Images scanned for vulnerabilities in CI/CD

## Next Steps

1. **Configure domain**: Update ingress hosts in sample-app.yaml
2. **Set up TLS**: Configure cert-manager with your domain
3. **Customize monitoring**: Add custom dashboards to Grafana
4. **Add applications**: Create new apps in gitops/apps/
5. **Set up backups**: Configure Velero for disaster recovery

## Support

- Check logs: `kubectl logs -n <namespace> <pod-name>`
- Argo CD UI: `make port-forward-argocd`
- Grafana dashboards: `make port-forward-grafana`
- GitHub Issues: Report problems in the repository
