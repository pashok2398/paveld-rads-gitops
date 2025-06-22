# Pavel's GitOps Repository

This repository contains the GitOps configuration for deploying applications using ArgoCD and KRO (Kubernetes Resource Orchestrator).

## Repository Structure

```
paveld-rads-gitops/
├── README.md
├── infrastructure/          # Infrastructure components
│   ├── kro/                # KRO installation
│   ├── argocd/             # ArgoCD applications and configuration
│   └── traefik/            # Traefik middleware configuration
├── platform/               # Platform templates and RGDs
│   └── resource-graph-definitions/
├── environments/           # Environment-specific configurations
│   ├── dev/
│   ├── staging/
│   └── prod/
└── legacy/                 # Legacy Helm charts (during migration)
```

## Getting Started

### Prerequisites

- K3s cluster with Traefik
- ArgoCD installed
- KRO installed

### Installation Steps

1. **Install KRO**:
   ```bash
   kubectl apply -f infrastructure/kro/install.yaml
   ```

2. **Deploy ArgoCD Applications**:
   ```bash
   kubectl apply -f infrastructure/argocd/applications/
   ```

3. **Deploy ResourceGraphDefinitions**:
   ```bash
   kubectl apply -f platform/resource-graph-definitions/
   ```

## Usage

### Creating a New Application

1. Create an instance file in the appropriate environment directory
2. Commit and push to Git
3. ArgoCD will automatically sync the changes

### Environment Promotion

Applications are promoted through environments by updating the image tags in instance files:
- `dev/` → `staging/` → `prod/`

## KRO Resources

This repository uses KRO ResourceGraphDefinitions for:
- **WebApp**: Standard web application with Deployment, Service, and Ingress
- **Database**: Database deployment with persistent storage
- **Microservice**: Lightweight microservice template

## Monitoring

- ArgoCD UI: `http://argocd.local`
- Application status can be monitored through ArgoCD dashboard
- Resource health is tracked via KRO status conditions

## Support

For issues and questions, please check the ArgoCD and KRO documentation:
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [KRO Docs](https://kro.run/docs/)