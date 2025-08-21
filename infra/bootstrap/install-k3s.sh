#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running on Raspberry Pi
check_raspberry_pi() {
    log_info "Checking if running on Raspberry Pi..."
    if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        log_warn "This script is optimized for Raspberry Pi but will continue anyway"
    else
        log_info "Raspberry Pi detected"
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check memory (minimum 2GB recommended)
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    
    if [ $MEMORY_GB -lt 2 ]; then
        log_warn "System has ${MEMORY_GB}GB RAM. 2GB+ recommended for k3s with monitoring stack"
    else
        log_info "Memory check passed: ${MEMORY_GB}GB RAM available"
    fi
    
    # Check disk space (minimum 10GB free)
    DISK_FREE_GB=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [ $DISK_FREE_GB -lt 10 ]; then
        log_error "Insufficient disk space. ${DISK_FREE_GB}GB free, 10GB+ required"
        exit 1
    else
        log_info "Disk space check passed: ${DISK_FREE_GB}GB free"
    fi
}

# Setup USB storage
setup_usb_storage() {
    log_info "Setting up USB storage..."
    
    # Create mount point
    sudo mkdir -p /mnt/usb-data
    
    # Check if USB device exists
    if [ ! -b /dev/sda1 ]; then
        log_error "USB device /dev/sda1 not found. Please connect USB drive and ensure it's formatted as ext4"
        log_info "To format: sudo mkfs.ext4 /dev/sda1"
        exit 1
    fi
    
    # Mount USB drive
    if ! mountpoint -q /mnt/usb-data; then
        log_info "Mounting USB drive..."
        sudo mount /dev/sda1 /mnt/usb-data
        
        # Add to fstab if not already present
        if ! grep -q "/mnt/usb-data" /etc/fstab; then
            echo "/dev/sda1 /mnt/usb-data ext4 defaults 0 2" | sudo tee -a /etc/fstab
            log_info "Added USB mount to /etc/fstab"
        fi
    else
        log_info "USB drive already mounted"
    fi
    
    # Set permissions
    sudo chown -R $USER:$USER /mnt/usb-data
    
    # Create storage directories
    mkdir -p /mnt/usb-data/{postgres,prometheus,loki,velero}
    log_info "Created storage directories on USB drive"
}

# Install k3s
install_k3s() {
    log_info "Installing k3s..."
    
    # Check if k3s is already installed
    if command -v k3s &> /dev/null; then
        log_info "k3s is already installed"
        return 0
    fi
    
    # Install k3s with specific configuration for Pi
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="
        --disable traefik 
        --disable servicelb 
        --write-kubeconfig-mode 644
        --kube-apiserver-arg=feature-gates=RemoveSelfLink=false
        --kubelet-arg=eviction-hard=memory.available<100Mi
        --kubelet-arg=eviction-soft=memory.available<300Mi
        --kubelet-arg=eviction-soft-grace-period=memory.available=1m30s
    " sh -
    
    # Wait for k3s to be ready
    log_info "Waiting for k3s to be ready..."
    sleep 30
    
    # Set up kubeconfig for current user
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    
    # Wait for node to be ready
    timeout=300
    while [ $timeout -gt 0 ]; do
        if kubectl get nodes | grep -q Ready; then
            log_info "k3s node is ready"
            break
        fi
        log_info "Waiting for k3s node to be ready... (${timeout}s remaining)"
        sleep 10
        timeout=$((timeout - 10))
    done
    
    if [ $timeout -le 0 ]; then
        log_error "Timeout waiting for k3s node to be ready"
        exit 1
    fi
}

# Install required tools
install_tools() {
    log_info "Installing required tools..."
    
    # Update package list
    sudo apt-get update
    
    # Install curl, wget, unzip if not present
    sudo apt-get install -y curl wget unzip
    
    # Install kubectl if not present (k3s includes it, but ensure it's in PATH)
    if ! command -v kubectl &> /dev/null; then
        log_info "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    # Install helm
    if ! command -v helm &> /dev/null; then
        log_info "Installing Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Install terraform (optional, for infrastructure management)
    if ! command -v terraform &> /dev/null; then
        log_info "Installing Terraform..."
        wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_arm64.zip
        unzip terraform_1.6.0_linux_arm64.zip
        sudo mv terraform /usr/local/bin/
        rm terraform_1.6.0_linux_arm64.zip
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check k3s status
    if ! systemctl is-active --quiet k3s; then
        log_error "k3s service is not running"
        exit 1
    fi
    
    # Check kubectl connectivity
    if ! kubectl get nodes &> /dev/null; then
        log_error "kubectl cannot connect to cluster"
        exit 1
    fi
    
    # Check USB storage
    if ! mountpoint -q /mnt/usb-data; then
        log_error "USB storage is not mounted"
        exit 1
    fi
    
    log_info "Installation verification completed successfully"
    
    # Display cluster info
    echo ""
    log_info "Cluster Information:"
    kubectl get nodes
    echo ""
    kubectl get pods -A
}

# Main execution
main() {
    log_info "Starting k3s installation for Raspberry Pi GitOps platform"
    
    check_raspberry_pi
    check_requirements
    setup_usb_storage
    install_tools
    install_k3s
    verify_installation
    
    log_info "k3s installation completed successfully!"
    log_info "Next steps:"
    log_info "1. Run 'make bootstrap' to deploy the GitOps platform"
    log_info "2. Use 'make port-forward-grafana' to access monitoring"
    log_info "3. Use 'make port-forward-argocd' to access GitOps dashboard"
}

# Run main function
main "$@"