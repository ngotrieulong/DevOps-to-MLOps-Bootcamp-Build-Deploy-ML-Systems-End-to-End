#!/bin/bash

# ============================================
# Deploy Kubeflow Pipeline Script
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="kubeflow"
IMAGE_NAME="house-price-predictor"
IMAGE_TAG="latest"
REGISTRY="${DOCKER_REGISTRY:-localhost:5000}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Deploying MLOps Pipeline to Kubeflow${NC}"
echo -e "${BLUE}============================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
echo -e "\n${BLUE}[1/8] Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi
print_status "kubectl found"

if ! command -v docker &> /dev/null; then
    print_error "docker is not installed"
    exit 1
fi
print_status "docker found"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_status "Kubernetes cluster is accessible"

# Build Docker image
echo -e "\n${BLUE}[2/8] Building Docker image...${NC}"
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
print_status "Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"

# Tag and push image (if using remote registry)
if [ "$REGISTRY" != "localhost:5000" ]; then
    echo -e "\n${BLUE}[3/8] Pushing image to registry...${NC}"
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    docker push ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
    print_status "Image pushed to ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
    echo -e "\n${BLUE}[3/8] Skipping push (using local registry)${NC}"
    print_warning "Using local Docker images"
fi

# Create namespace if it doesn't exist
echo -e "\n${BLUE}[4/8] Creating namespace...${NC}"
if kubectl get namespace ${NAMESPACE} &> /dev/null; then
    print_warning "Namespace ${NAMESPACE} already exists"
else
    kubectl create namespace ${NAMESPACE}
    print_status "Namespace ${NAMESPACE} created"
fi

# Apply Kubernetes resources
echo -e "\n${BLUE}[5/8] Applying Kubernetes resources...${NC}"
kubectl apply -f .githup/workflow/k8s-resources.yaml
print_status "Kubernetes resources applied"

# Wait for MLflow to be ready
echo -e "\n${BLUE}[6/8] Waiting for MLflow server to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s \
    deployment/mlflow-server -n ${NAMESPACE} || print_warning "MLflow may not be ready yet"
print_status "MLflow server is ready"

# Deploy the Kubeflow pipeline
echo -e "\n${BLUE}[7/8] Deploying Kubeflow pipeline...${NC}"

# Check if Argo Workflows is installed
if ! kubectl get crd workflows.argoproj.io &> /dev/null; then
    print_warning "Argo Workflows CRD not found. Installing Argo..."
    kubectl create namespace argo || true
    kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
    print_status "Argo Workflows installed"

    # Wait for Argo to be ready
    echo "Waiting for Argo to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/workflow-controller -n argo || print_warning "Argo may not be ready yet"
fi

# Submit the pipeline
kubectl apply -f .githup/workflow/kubeflow-pipeline.yaml
print_status "Pipeline submitted to Kubeflow"

# Get pipeline status
echo -e "\n${BLUE}[8/8] Checking deployment status...${NC}"

# List workflows
echo -e "\n${YELLOW}Recent workflows:${NC}"
kubectl get workflows -n ${NAMESPACE} --sort-by=.metadata.creationTimestamp | tail -5

# Get pods
echo -e "\n${YELLOW}Pods in namespace ${NAMESPACE}:${NC}"
kubectl get pods -n ${NAMESPACE}

# Get services
echo -e "\n${YELLOW}Services:${NC}"
kubectl get services -n ${NAMESPACE}

echo -e "\n${GREEN}============================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}============================================${NC}"

echo -e "\n${BLUE}Useful commands:${NC}"
echo -e "  View workflows:    ${YELLOW}kubectl get workflows -n ${NAMESPACE}${NC}"
echo -e "  View pods:         ${YELLOW}kubectl get pods -n ${NAMESPACE}${NC}"
echo -e "  View logs:         ${YELLOW}kubectl logs -n ${NAMESPACE} <pod-name>${NC}"
echo -e "  Port-forward API:  ${YELLOW}kubectl port-forward -n ${NAMESPACE} svc/house-price-predictor 8000:8000${NC}"
echo -e "  Port-forward MLflow: ${YELLOW}kubectl port-forward -n ${NAMESPACE} svc/mlflow-server 5000:5000${NC}"
echo -e "  Delete pipeline:   ${YELLOW}kubectl delete workflow -n ${NAMESPACE} --all${NC}"

echo -e "\n${BLUE}Access the services:${NC}"
echo -e "  API:     ${YELLOW}http://localhost:8000${NC}"
echo -e "  MLflow:  ${YELLOW}http://localhost:5000${NC}"
echo -e "  Health:  ${YELLOW}http://localhost:8000/health${NC}"
echo -e "  Docs:    ${YELLOW}http://localhost:8000/docs${NC}"

# Optional: Port forward automatically
read -p "Do you want to port-forward the API now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Port-forwarding API to localhost:8000...${NC}"
    kubectl port-forward -n ${NAMESPACE} svc/house-price-predictor 8000:8000
fi
