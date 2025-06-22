#!/bin/bash

# bootstrap.sh - Bootstrap the GitOps repository with KRO and ArgoCD

set -e

echo "🚀 Bootstrapping GitOps Repository with KRO and ArgoCD..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is required but not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Install KRO
install_kro() {
    print_status "Installing KRO..."
    
    # Create namespace
    kubectl create namespace kro-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install KRO
    kubectl apply -f https://github.com/kro-run/kro/releases/latest/download/install.yaml
    
    # Wait for KRO to be ready
    print_status "Waiting for KRO to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kro-controller-manager -n kro-system
    
    print_success "KRO installed successfully"
}

# Deploy platform resources
deploy_platform() {
    print_status "Deploying platform ResourceGraphDefinitions..."
    
    kubectl apply -f platform/resource-graph-definitions/
    
    # Wait for RGDs to be ready
    sleep 10
    kubectl get rgd
    
    print_success "Platform resources deployed"
}

# Deploy ArgoCD applications
deploy_argocd_apps() {
    print_status "Deploying ArgoCD applications..."
    
    # Apply individual applications first
    kubectl apply -f infrastructure/argocd/applications/
    
    # Wait a bit then apply ApplicationSets
    sleep 5
    kubectl apply -f infrastructure/argocd/applicationsets/
    
    print_success "ArgoCD applications deployed"
}

# Deploy Traefik middleware
deploy_traefik_middleware() {
    print_status "Deploying Traefik middleware..."
    
    kubectl apply -f infrastructure/traefik/middleware.yaml
    
    print_success "Traefik middleware deployed"
}

# Setup /etc/hosts entries
setup_hosts() {
    print_status "Setting up /etc/hosts entries..."
    
    print_warning "Please add the following entries to your /etc/hosts file:"
    echo ""
    echo "127.0.0.1 argocd.local"
    echo "127.0.0.1 paveld-webapp-dev.local"
    echo "127.0.0.1 paveld-webapp-staging.local"
    echo ""
    print_warning "For production, use your actual domain instead of .local"
}

# Main execution
main() {
    echo "🎯 GitOps Bootstrap Script"
    echo "=========================="
    
    check_prerequisites
    install_kro
    deploy_platform
    deploy_traefik_middleware
    deploy_argocd_apps
    setup_hosts
    
    echo ""
    print_success "Bootstrap completed successfully!"
    echo ""
    print_status "Next steps:"
    echo "1. Add the /etc/hosts entries shown above"
    echo "2. Access ArgoCD at http://argocd.local"
    echo "3. Monitor applications in ArgoCD dashboard"
    echo "4. Test dev environment at http://paveld-webapp-dev.local"
    echo ""
    print_status "Useful commands:"
    echo "kubectl get rgd                              # Check ResourceGraphDefinitions"
    echo "kubectl get applications -n argocd          # Check ArgoCD applications"
    echo "kubectl get webapp,database --all-namespaces # Check KRO instances"
    echo "kubectl get pods --all-namespaces           # Check all pods"
}

# Run the script
main "$@"