#!/bin/bash

# bootstrap.sh - Bootstrap the GitOps repository with KRO and ArgoCD

set -e
trap 'print_error "Script failed on line $LINENO"' ERR

echo "🚀 Bootstrapping GitOps Repository with KRO and ArgoCD..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success()   { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning()   { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()     { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    for cmd in kubectl minikube helm jq; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd is required but not installed"
            exit 1
        fi
    done

    print_success "Prerequisites check passed"
}

# Create KIND cluster
create_kind_cluster() {
    print_status "Creating KIND cluster..."

#     cat <<EOF > /tmp/kind-config.yaml
# kind: Cluster
# apiVersion: kind.x-k8s.io/v1alpha4
# nodes:
# - role: control-plane
#   extraPortMappings:
#   - containerPort: 80
#     hostPort: 80
#     protocol: TCP
#   - containerPort: 443
#     hostPort: 443
#     protocol: TCP
# EOF
#     kind create cluster --config=/tmp/kind-config.yaml

    minikube start --driver=none

    kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml

    sleep 2

    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s

    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    rm /tmp/kind-config.yaml


    print_success "KIND cluster created successfully"
}

# Install KRO
install_kro() {
    print_status "Installing KRO..."

    export KRO_VERSION=$(curl -sL https://api.github.com/repos/kro-run/kro/releases/latest | jq -r '.tag_name | ltrimstr("v")')

    helm install kro oci://ghcr.io/kro-run/kro/kro \
        --namespace kro \
        --create-namespace \
        --version=${KRO_VERSION}

    print_status "Waiting for KRO to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kro -n kro

    print_success "KRO installed successfully"
}

# Install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."

    kubectl create namespace argocd || true
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl apply -f infrastructure/argocd/argocd-infra/

    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=180s deployment/argocd-server -n argocd

    ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 --decode)

    print_success "ArgoCD installed successfully"
    echo "🌐 ArgoCD admin password: ${ARGO_PWD}"
}

# Deploy platform RGD definitions
deploy_platform() {
    print_status "Deploying platform ResourceGraphDefinitions..."

    kubectl apply -f platform/resource-graph-definitions/
    sleep 10
    kubectl get rgd

    print_success "Platform resources deployed"
}

# Deploy ArgoCD apps
deploy_argocd_apps() {
    print_status "Deploying ArgoCD applications..."

    kubectl apply -f infrastructure/argocd/applications/
    sleep 5
    kubectl apply -f infrastructure/argocd/applicationsets/

    print_success "ArgoCD applications deployed"
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
    create_kind_cluster
    install_kro
    install_argocd
    deploy_platform
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
