# K3s + ArgoCD GitOps Platform

[![Ansible](https://img.shields.io/badge/Ansible-2.15+-red.svg)](https://ansible.com)
[![K3s](https://img.shields.io/badge/K3s-v1.28.5-blue.svg)](https://k3s.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.9.3-green.svg)](https://argoproj.github.io/cd/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Automated provisioning of a lightweight Kubernetes cluster using **K3s** and **GitOps** deployment with **ArgoCD**. This project demonstrates infrastructure automation and modern deployment practices suitable for development, testing, and small production environments.

## Architecture

```
┌─────────────────────────────────────────────┐
│                Control Node                 │
│            (Ansible Controller)             │
└─────────────────┬───────────────────────────┘
                  │ SSH + Ansible
                  ▼
┌─────────────────────────────────────────────┐
│              Target Hosts                   │
│  ┌─────────────────────────────────────────┐│
│  │            K3s Cluster                  ││
│  │  ┌─────────────┐  ┌─────────────────┐   ││
│  │  │   ArgoCD    │  │   Demo Apps     │   ││
│  │  │  (GitOps)   │  │   (Managed by   │   ││
│  │  │             │  │    ArgoCD)      │   ││
│  │  └─────────────┘  └─────────────────┘   ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

## What This Project Does

1. **Provisions K3s** - Installs lightweight Kubernetes on target hosts
2. **Deploys ArgoCD** - Sets up GitOps controller for application management
3. **Demonstrates GitOps** - Shows how applications are deployed and managed via Git

## Quick Start

### Prerequisites

- **Ansible** 2.15+ with `kubernetes.core` collection
- **Python** 3.8+ with `kubernetes` library
- **SSH access** to target hosts
- **kubectl** for cluster interaction

### Installation

```bash
# Clone repository
git clone https://github.com/YOUR_USERNAME/k3s-argocd-rasp-pi.git
cd k3s-argocd-rasp-pi

# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Update inventory with your hosts
vim inventories/hosts.ini
```

### Deploy K3s Cluster

```bash
# Install K3s on target hosts
ansible-playbook -i inventories/hosts.ini playbooks/k3s.yml

# Verify cluster is ready
kubectl get nodes
```

### Deploy ArgoCD

```bash
# Install ArgoCD
ansible-playbook playbooks/argocd.yml

# Verify ArgoCD is running
kubectl get pods -n argocd

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 (admin/password from playbook output)
```

### Deploy Demo Application

```bash
# Apply demo application via ArgoCD
kubectl apply -f manifests/demo-app.yaml

# Watch ArgoCD sync the application
kubectl get applications -n argocd
```

## Example ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Project Structure

```
├── inventories/
│   └── hosts.ini              # Ansible inventory
├── playbooks/
│   ├── k3s.yml               # K3s installation
│   └── argocd.yml            # ArgoCD deployment
├── roles/
│   ├── k3s/                  # K3s installation role
│   └── argocd/               # ArgoCD deployment role
├── manifests/
│   └── demo-app.yaml         # Example ArgoCD application
├── ansible.cfg               # Ansible configuration
└── requirements.yml          # Ansible collections
```

## Configuration

### Inventory Setup

Edit `inventories/hosts.ini`:

```ini
[k3s_cluster]
k3s-node1 ansible_host=192.168.1.100
k3s-node2 ansible_host=192.168.1.101

[k3s_cluster:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### Customization

- **K3s version**: Edit `roles/k3s/defaults/main.yml`
- **ArgoCD version**: Edit `roles/argocd/defaults/main.yml`
- **K3s options**: Modify `k3s_server_options` in defaults

## Why This Matters

This project demonstrates:

- **Infrastructure as Code** - Reproducible cluster provisioning
- **GitOps Principles** - Declarative application deployment
- **Modern DevOps Practices** - Automation, version control, and observability
- **Scalable Architecture** - From single node to multi-node clusters

Perfect for:

- Development environments
- CI/CD pipelines
- Learning Kubernetes and GitOps
- Small production workloads

## Troubleshooting

### Common Issues

**K3s installation fails:**

```bash
# Check connectivity
ansible k3s_cluster -m ping

# Verify sudo access
ansible k3s_cluster -m shell -a "sudo whoami" --become
```

**ArgoCD not accessible:**

```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Applications not syncing:**

```bash
# Check application status
kubectl get applications -n argocd

# View ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes on clean VMs
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.
