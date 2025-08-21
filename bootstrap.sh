#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root"
   exit 1
fi

log_info "🚀 Starting Raspberry Pi k3s GitOps Platform Bootstrap"
log_info "This will install and configure:"
log_info "  - k3s Kubernetes cluster"
log_info "  - Argo CD GitOps controller"
log_info "  - Complete observability stack"
log_info "  - Sample three-tier application"
echo ""

# Step 1: Check prerequisites
log_step "1/6 Checking prerequisites..."

# Check if we're on a Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    log_warn "Not running on Raspberry Pi - continuing anyway"
fi

# Check memory
MEMORY_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ $MEMORY_GB -lt 3 ]; then
    log_warn "System has ${MEMORY_GB}GB RAM. 4GB+ recommended for full stack"
fi

# Check disk space
DISK_FREE_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
if [ $DISK_FREE_GB -lt 10 ]; then
    log_error "Insufficient disk space. ${DISK_FREE_GB}GB free, 10GB+ required"
    exit 1
fi

# Check if USB storage is mounted
if ! mountpoint -q /mnt/usb-data; then
    log_error "USB storage not mounted at /mnt/usb-data"
    log_info "Please run: make mount-usb"
    exit 1
fi

log_info "✅ Prerequisites check passed"

# Step 2: Install k3s
log_step "2/6 Installing k3s..."

if command -v k3s &> /dev/null; then
    log_info "k3s already installed"
else
    log_info "Installing k3s with Pi-optimized settings..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb --write-kubeconfig-mode 644" sh -
    
    # Set up kubeconfig
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
fi

# Wait for k3s to be ready
log_info "Waiting for k3s to be ready..."
timeout=300
while [ $timeout -gt 0 ]; do
    if kubectl get nodes | grep -q Ready; then
        log_info "✅ k3s is ready"
        break
    fi
    sleep 5
    timeout=$((timeout - 5))
done

if [ $timeout -le 0 ]; then
    log_error "Timeout waiting for k3s to be ready"
    exit 1
fi

# Step 3: Install Argo CD
log_step "3/6 Installing Argo CD..."

if kubectl get namespace argocd &> /dev/null; then
    log_info "Argo CD namespace already exists"
else
    log_info "Creating Argo CD namespace and installing..."
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

# Wait for Argo CD to be ready
log_info "Waiting for Argo CD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

log_info "✅ Argo CD is ready"

# Step 4: Apply Terraform
log_step "4/6 Applying Terraform configurations..."

if command -v terraform &> /dev/null; then
    cd infra/terraform
    terraform init
    terraform apply -auto-approve
    cd ../..
    log_info "✅ Terraform applied"
else
    log_warn "Terraform not found - skipping infrastructure setup"
    log_info "You can install Terraform and run: cd infra/terraform && terraform init && terraform apply"
fi

# Step 5: Create storage directories
log_step "5/6 Setting up storage..."

log_info "Creating storage directories on USB drive..."
mkdir -p /mnt/usb-data/{postgres,prometheus,loki,velero}
log_info "✅ Storage directories created"

# Step 6: Deploy GitOps applications
log_step "6/6 Deploying GitOps applications..."

log_info "Applying root application..."
kubectl apply -f gitops/bootstrap/root-app.yaml

log_info "✅ Root application deployed"

# Final status
echo ""
log_info "🎉 Bootstrap completed successfully!"
echo ""
log_info "Next steps:"
log_info "1. Wait for applications to sync (5-10 minutes):"
log_info "   kubectl get applications -n argocd"
echo ""
log_info "2. Access services:"
log_info "   make port-forward-grafana    # http://localhost:3000 (admin/admin)"
log_info "   make port-forward-argocd     # http://localhost:8080"
echo ""
log_info "3. Check status:"
log_info "   make status"
echo ""
log_info "4. Get Argo CD admin password:"
log_info "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""

# Show current status
log_info "Current cluster status:"
kubectl get nodes
echo ""
kubectl get applications -n argocd 2>/dev/null || log_info "Applications will appear as Argo CD syncs..."

log_info "🚀 Your Raspberry Pi GitOps platform is ready!"