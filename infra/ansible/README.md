# Ansible Infrastructure

This directory contains Ansible playbooks and configurations for bootstrapping the k3s GitOps platform.

## Structure

```
ansible/
├── ansible.cfg          # Ansible configuration
├── inventory.yml        # Host inventory
├── requirements.yml     # Required collections
├── group_vars/         # Global variables
├── playbooks/          # Main playbooks
│   ├── bootstrap.yml   # Complete platform setup
│   ├── deploy-root-app.yml  # Deploy GitOps root app
│   └── tasks/          # Modular task files
└── templates/          # Jinja2 templates (if needed)
```

## Quick Start

```bash
# Install required collections
make setup-ansible

# Bootstrap entire platform
make bootstrap

# Deploy GitOps applications
make deploy-root-app
```

## What It Does

1. **USB Storage Setup** - Mounts and configures external storage
2. **k3s Installation** - Installs k3s with Pi optimizations
3. **Kubernetes Resources** - Creates namespaces, storage classes, PVCs
4. **Argo CD Setup** - Installs and configures Argo CD

## Customization

Edit `group_vars/all.yml` to customize:
- k3s version
- Storage sizes
- Mount points
- Cluster settings