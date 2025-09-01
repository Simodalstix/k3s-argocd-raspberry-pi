.PHONY: help setup-ansible bootstrap port-forward-grafana port-forward-argocd status clean sync-apps

# Default target
help:
	@echo "Available targets:"
	@echo "  setup-ansible          - Install Ansible collections"
	@echo "  bootstrap              - Bootstrap entire k3s GitOps platform"
	@echo "  deploy-root-app        - Deploy Argo CD root application"
	@echo "  port-forward-grafana   - Port forward Grafana (localhost:3000)"
	@echo "  port-forward-argocd    - Port forward Argo CD (localhost:8080)"
	@echo "  status                 - Show cluster status"
	@echo "  sync-apps              - Force sync all applications"
	@echo "  clean                  - Clean up all resources"

# Setup Ansible
setup-ansible:
	@echo "Installing Ansible collections..."
	cd infra/ansible && ansible-galaxy collection install -r requirements.yml

# Bootstrap the entire platform
bootstrap: setup-ansible
	@echo "Bootstrapping k3s GitOps platform with Ansible..."
	cd infra/ansible && ansible-playbook playbooks/bootstrap.yml
	@echo "Bootstrap complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Run 'make deploy-root-app' to deploy GitOps applications"
	@echo "2. Use 'make port-forward-grafana' to access monitoring"
	@echo "3. Use 'make port-forward-argocd' to access GitOps dashboard"

# Deploy root application
deploy-root-app:
	@echo "Deploying Argo CD root application..."
	cd infra/ansible && ansible-playbook playbooks/deploy-root-app.yml

# Port forward Grafana
port-forward-grafana:
	@echo "Port forwarding Grafana to localhost:3000..."
	@echo "Access Grafana at http://localhost:3000 (admin/admin)"
	kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Port forward Argo CD
port-forward-argocd:
	@echo "Port forwarding Argo CD to localhost:8080..."
	@echo "Access Argo CD at http://localhost:8080"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	kubectl port-forward -n argocd svc/argocd-server 8080:443

# Get cluster status
status:
	@echo "=== Cluster Status ==="
	kubectl get nodes
	@echo ""
	@echo "=== Argo CD Applications ==="
	kubectl get applications -n argocd
	@echo ""
	@echo "=== All Pods ==="
	kubectl get pods -A
	@echo ""
	@echo "=== Storage ==="
	kubectl get pv,pvc -A
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress -A

# Clean up resources
clean:
	@echo "Cleaning up resources..."
	@echo "This will remove all applications and data. Are you sure? [y/N]"
	@read -r REPLY; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		kubectl delete -f gitops/bootstrap/root-app.yaml --ignore-not-found; \
		kubectl delete namespace argocd monitoring loki ingress-nginx cert-manager velero --ignore-not-found; \
		sudo systemctl stop k3s; \
		sudo /usr/local/bin/k3s-uninstall.sh; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

# Build and push images (for development)
build-images:
	@echo "Building and pushing Docker images..."
	@echo "Building frontend..."
	cd apps/frontend && docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/YOUR_USERNAME/sample-frontend:latest --push .
	@echo "Building backend..."
	cd apps/backend && docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/YOUR_USERNAME/sample-backend:latest --push .
	@echo "Images built and pushed successfully!"

# Sync all Argo CD applications
sync-apps:
	@echo "Syncing all Argo CD applications..."
	kubectl patch application root -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
	@echo "Sync initiated. Check status with: kubectl get applications -n argocd"