#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
IMAGE_TAG=${2:-latest}

echo "🚀 GitHub Actions Manual Deployment Starting..."
echo "Environment: $ENVIRONMENT"
echo "Image Tag: $IMAGE_TAG"

# Check if kustomize is installed
if ! command -v kustomize &> /dev/null; then
    echo "📥 Installing Kustomize..."
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    sudo mv kustomize /usr/local/bin/
fi

# Load environment variables from .github/config
if [[ -f ".github/config/deploy_env_vars_${ENVIRONMENT}" ]]; then
    source ".github/config/deploy_env_vars_${ENVIRONMENT}"
    echo "✅ Environment variables loaded for $ENVIRONMENT"
else
    echo "❌ Environment configuration file not found: .github/config/deploy_env_vars_${ENVIRONMENT}"
    exit 1
fi

# Create namespace
echo "📝 Creating namespace phonebill-dg0504..."
kubectl create namespace phonebill-dg0504 --dry-run=client -o yaml | kubectl apply -f -

# Navigate to environment overlay directory
cd deployment/cicd/kustomize/overlays/${ENVIRONMENT}

echo "🔄 Updating image tags..."
# Services array
services=(api-gateway user-service bill-service product-service kos-mock)

# Update image tags for each service
for service in "${services[@]}"; do
  echo "   Updating $service..."
  kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/$service:${ENVIRONMENT}-${IMAGE_TAG}
done

echo "☸️  Deploying to Kubernetes..."
# Apply deployment
kubectl apply -k .

echo "⏳ Waiting for deployments to be ready..."
# Wait for each service deployment
for service in "${services[@]}"; do
  echo "   Checking $service..."
  kubectl rollout status deployment/$service -n phonebill-dg0504 --timeout=300s
done

echo "🔍 Health check..."
# API Gateway Health Check
GATEWAY_POD=$(kubectl get pod -n phonebill-dg0504 -l app=phonebill,app.kubernetes.io/name=api-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$GATEWAY_POD" ]]; then
  kubectl -n phonebill-dg0504 exec $GATEWAY_POD -- curl -f http://localhost:8080/actuator/health || echo "⚠️  Health check failed, but deployment completed"
else
  echo "⚠️  API Gateway pod not found, skipping health check"
fi

echo ""
echo "📋 Service Information:"
echo "========================"
kubectl get pods -n phonebill-dg0504
echo ""
kubectl get services -n phonebill-dg0504
echo ""
kubectl get ingress -n phonebill-dg0504
echo ""

echo "✅ GitHub Actions deployment completed successfully!"
