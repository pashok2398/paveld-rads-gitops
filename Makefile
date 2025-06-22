# Makefile for GitOps Repository Operations

.PHONY: help bootstrap install-kro deploy-platform deploy-apps status clean

# Default target
help:
	@echo "GitOps Repository Management"
	@echo "============================"
	@echo "Available targets:"
	@echo "  bootstrap      - Full bootstrap of KRO and ArgoCD"
	@echo "  install-kro    - Install KRO only"
	@echo "  deploy-platform - Deploy ResourceGraphDefinitions"
	@echo "  deploy-apps    - Deploy ArgoCD applications"
	@echo "  status         - Show status of all resources"
	@echo "  sync-apps      - Force sync all ArgoCD applications"
	@echo "  logs           - Show logs from key components"
	@echo "  clean          - Clean up all resources"
	@echo "  test-dev       - Test dev environment"

# Full bootstrap
bootstrap:
	@echo "🚀 Running full bootstrap..."
	./bootstrap.sh

# Install KRO only
install-kro:
	@echo "📦 Installing KRO..."
	kubectl apply -f https://github.com/kro-run/kro/releases/latest/download/install.yaml
	kubectl wait --for=condition=available --timeout=300s deployment/kro-controller-manager -n kro-system

# Deploy platform ResourceGraphDefinitions
deploy-platform:
	@echo "🏗️ Deploying platform resources..."
	kubectl apply -f platform/resource-graph-definitions/
	@sleep 5
	kubectl get rgd

# Deploy ArgoCD applications
deploy-apps:
	@echo "🚀 Deploying ArgoCD applications..."
	kubectl apply -f infrastructure/argocd/applications/
	kubectl apply -f infrastructure/argocd/applicationsets/

# Show status of all resources
status:
	@echo "📊 Resource Status"
	@echo "=================="
	@echo "KRO System:"
	kubectl get pods -n kro-system
	@echo ""
	@echo "ResourceGraphDefinitions:"
	kubectl get rgd
	@echo ""
	@echo "ArgoCD Applications:"
	kubectl get applications -n argocd
	@echo ""
	@echo "KRO Instances:"
	kubectl get webapp,database --all-namespaces
	@echo ""
	@echo "Ingress Routes:"
	kubectl get ingressroute --all-namespaces

# Force sync all ArgoCD applications
sync-apps:
	@echo "🔄 Syncing ArgoCD applications..."
	kubectl patch app kro-platform -n argocd --type merge -p='{"operation":{"sync":{"revision":"HEAD"}}}'
	kubectl patch app dev-webapp -n argocd --type merge -p='{"operation":{"sync":{"revision":"HEAD"}}}'
	kubectl patch app dev-database -n argocd --type merge -p='{"operation":{"sync":{"revision":"HEAD"}}}'

# Show logs from key components
logs:
	@echo "📋 Component Logs"
	@echo "================"
	@echo "KRO Controller:"
	kubectl logs -n kro-system deployment/kro-controller-manager --tail=20
	@echo ""
	@echo "ArgoCD Server:"
	kubectl logs -n argocd deployment/argocd-server --tail=20

# Test dev environment
test-dev:
	@echo "🧪 Testing dev environment..."
	@echo "Checking if resources are ready..."
	kubectl wait --for=condition=available --timeout=60s deployment/paveld-webapp -n dev || true
	@echo ""
	@echo "Dev webapp status:"
	kubectl get webapp paveld-webapp-dev -n dev -o wide || echo "WebApp not found"
	@echo ""
	@echo "Dev database status:"
	kubectl get database paveld-db-dev -n dev -o wide || echo "Database not found"
	@echo ""
	@echo "Test endpoints:"
	@echo "- Add '127.0.0.1 paveld-webapp-dev.local' to /etc/hosts"
	@echo "- Visit: http://paveld-webapp-dev.local"

# Clean up all resources
clean:
	@echo "🧹 Cleaning up resources..."
	@echo "This will delete all KRO instances and ArgoCD applications"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	kubectl delete applications --all -n argocd || true
	kubectl delete webapp,database --all --all-namespaces || true
	kubectl delete rgd --all || true
	@echo "Cleanup completed"

# Install dependencies for local development
deps:
	@echo "📦 Installing development dependencies..."
	@command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required"; exit 1; }
	@command -v yq >/dev/null 2>&1 || { echo "Installing yq..."; sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq; }
	@echo "Dependencies installed"

# Validate YAML files
validate:
	@echo "✅ Validating YAML files..."
	@find . -name "*.yaml" -o -name "*.yml" | xargs -I {} sh -c 'echo "Validating {}" && yq eval . {} > /dev/null'
	@echo "All YAML files are valid"