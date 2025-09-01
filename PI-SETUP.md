# Raspberry Pi Setup Guide

## Prerequisites

- Raspberry Pi 4 (4GB+ RAM recommended)
- Ubuntu Server 22.04 LTS (ARM64)
- SSH access enabled
- Static IP address configured

## Initial Pi Configuration

### 1. Flash Ubuntu Server
```bash
# Download Ubuntu Server 22.04 LTS ARM64
# Flash to SD card using Raspberry Pi Imager
# Enable SSH in boot partition (create empty 'ssh' file)
```

### 2. First Boot Setup
```bash
# SSH into Pi (default user: ubuntu, password: ubuntu)
ssh ubuntu@your-pi-ip

# Change default password
sudo passwd ubuntu

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y python3 python3-pip curl
```

### 3. SSH Key Setup
```bash
# From your local machine
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
ssh-copy-id ubuntu@your-pi-ip

# Test passwordless SSH
ssh ubuntu@your-pi-ip
```

### 4. Configure Static IP (Optional)
```bash
# Edit netplan configuration
sudo nano /etc/netplan/50-cloud-init.yaml

# Example configuration:
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]

# Apply configuration
sudo netplan apply
```

## Update Ansible Inventory

Edit `inventories/hosts.ini`:
```ini
[k3s_cluster]
raspberry-pi ansible_host=YOUR_PI_IP

[k3s_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

## Test Connection

```bash
# Test Ansible connectivity
ansible k3s_cluster -m ping

# Test sudo access
ansible k3s_cluster -m shell -a "sudo whoami" --become
```

## Deploy Platform

```bash
# Install collections
make setup

# Deploy K3s
make install-k3s

# Deploy ArgoCD
make install-argocd

# Deploy demo app
make deploy-demo
```