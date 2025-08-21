.PHONY: help mount-usb install-k3s install-argocd bootstrap port-forward-grafana port-forward-argocd backup restore clean status

# Default target
help:
	@echo "Available targets:"
	@echo "  mount-usb              - Mount USB storage and configure fstab"
	@echo "  install-k3s            - Install k3s cluster"
	@echo "  install-argocd         - Install Argo CD using official manifests"
	@echo "  bootstrap              - Bootstrap entire k3s GitOps platform"
	@echo "  port-forward-grafana   - Port forward Grafana (localhost:3000)"
	@echo "  port-forward-argocd    - Port forward Argo CD (localhost:8080)"
	@echo "  status                 - Show cluster status"
	@echo "  clean                  - Clean up all resources"

# Mount USB storage
mount-usb:
	@echo "Mounting USB storage..."
	sudo mkdir -p /mnt/usb-data
	@echo "Please ensure USB drive is connected and run:"
	@echo "sudo fdisk -l  # to identify your USB device (usually /dev/sda1)"
	@echo "sudo mkfs.ext4 /dev/sda1  # format if needed"
	@echo "sudo mount /dev/sda1 /mnt/usb-data"
	@echo "sudo chown -R $$USER:$$USER /mnt/usb-data"
	@echo "echo '/dev/sda1 /mnt/usb-data ext4 defaults 0 2' | sudo tee -a /etc/fstab"

# Install k3s
install-k3s:
	@echo "Installing k3s..."
	curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --disable servicelb --write-kubeconfig-mode 644" sh -
	@echo "Waiting for k3s to be ready..."
	sleep 30
	kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install Argo CD using official manifests
install-argocd:
	@echo "Installing Argo CD..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for Argo CD to be ready..."
	kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Bootstrap the entire platform
bootstrap: install-k3s install-argocd
	@echo "Bootstrapping k3s GitOps platform..."
	@echo "Step 1: Creating storage directories..."
	mkdir -p /mnt/usb-data/{postgres,prometheus,loki,velero}
	@echo "Step 2: Applying Terraform configurations..."
	cd infra/terraform && terraform init && terraform apply -auto-approve
	@echo "Step 3: Applying root application..."
	kubectl apply -f gitops/bootstrap/root-app.yaml
	@echo "Bootstrap complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Wait for all applications to sync (check with: kubectl get applications -n argocd)"
	@echo "2. Use 'make port-forward-grafana' to access monitoring"
	@echo "3. Use 'make port-forward-argocd' to access GitOps dashboard"

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
		kubectl delete namespace argocd monitoring logging ingress-nginx cert-manager velero --ignore-not-found; \
		cd infra/terraform && terraform destroy -auto-approve; \
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