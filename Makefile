.PHONY: help setup check install-k3s install-argocd deploy-demo status clean

# Default target
help:
	@echo "K3s + ArgoCD GitOps Platform"
	@echo "Available targets:"
	@echo "  setup                  - Install Ansible collections"
	@echo "  check                  - Test Pi connectivity and requirements"
	@echo "  install-k3s            - Install K3s cluster"
	@echo "  install-argocd         - Deploy ArgoCD"
	@echo "  deploy-demo            - Deploy demo application"
	@echo "  port-forward-argocd    - Access ArgoCD UI (localhost:8080)"
	@echo "  status                 - Show cluster status"
	@echo "  clean                  - Clean up resources"

# Setup
setup:
	@echo "Installing Ansible collections..."
	ansible-galaxy collection install -r requirements.yml

# Check Pi connectivity
check:
	@echo "Checking Pi connectivity and requirements..."
	ansible-playbook playbooks/check-connectivity.yml

# Install K3s
install-k3s: setup
	@echo "Installing K3s cluster..."
	ansible-playbook playbooks/k3s.yml
	@echo "Verifying cluster..."
	ssh simo-pi "kubectl get nodes"

# Install ArgoCD
install-argocd:
	@echo "Deploying ArgoCD..."
	ansible-playbook playbooks/argocd.yml
	@echo "Verifying ArgoCD..."
	ssh simo-pi "kubectl get pods -n argocd"

# Deploy demo application
deploy-demo:
	@echo "Copying manifests to Pi..."
	scp manifests/*.yaml simo-pi:/tmp/
	@echo "Creating namespaces..."
	ssh simo-pi "kubectl apply -f /tmp/namespaces.yaml"
	@echo "Deploying demo application..."
	ssh simo-pi "kubectl apply -f /tmp/demo-app.yaml"
	@echo "Check status: ssh simo-pi 'kubectl get applications -n argocd'"



# Port forward ArgoCD
port-forward-argocd:
	@echo "Port forwarding ArgoCD to localhost:8080..."
	@echo "Access ArgoCD at https://localhost:8080"
	@echo "Username: admin"
	@echo "Password: $$(ssh simo-pi 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d')"
	ssh simo-pi "kubectl port-forward -n argocd svc/argocd-server 8080:443"

# Get cluster status
status:
	@echo "=== Cluster Status ==="
	ssh simo-pi "kubectl get nodes"
	@echo ""
	@echo "=== ArgoCD Applications ==="
	ssh simo-pi "kubectl get applications -n argocd"
	@echo ""
	@echo "=== All Pods ==="
	ssh simo-pi "kubectl get pods -A"

# Clean up resources
clean:
	@echo "This will uninstall K3s and remove all data. Continue? [y/N]"
	@read -r REPLY; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

