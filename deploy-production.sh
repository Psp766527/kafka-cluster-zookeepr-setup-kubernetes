#!/bin/bash

# =============================================================================
# PRODUCTION DEPLOYMENT SCRIPT FOR KAFKA & ZOOKEEPER
# =============================================================================
# This script deploys a complete production-ready Kafka and Zookeeper cluster
# with monitoring, security, and management UI.
# 
# IMPORTANT NOTES:
# - Run this script after reviewing and customizing the configuration files
# - Ensure you have kubectl configured and cluster access
# - Check storage classes and resource availability before deployment
# - Follow the deployment order for proper initialization
# =============================================================================

set -e  # Exit on any error

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kubectl is configured
    if ! kubectl cluster-info &> /dev/null; then
        print_error "kubectl is not configured or cluster is not accessible"
        exit 1
    fi
    
    # Check if namespace exists, create if not
    if ! kubectl get namespace default &> /dev/null; then
        print_warning "Default namespace not found, creating..."
        kubectl create namespace default
    fi
    
    # Apply namespace configuration
    print_status "Applying namespace configuration..."
    kubectl apply -f namespace-config.yaml
    
    # Check available storage classes
    print_status "Available storage classes:"
    kubectl get storageclass
    
    print_success "Prerequisites check completed"
}

# Function to deploy Zookeeper
deploy_zookeeper() {
    print_status "Deploying Zookeeper ensemble..."
    
    kubectl apply -f zookeeper-production.yaml
    
    print_status "Waiting for Zookeeper pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s
    
    print_success "Zookeeper deployment completed"
}

# Function to deploy Kafka
deploy_kafka() {
    print_status "Deploying Kafka cluster..."
    
    kubectl apply -f kafka-production.yaml
    
    print_status "Waiting for Kafka pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s
    
    print_success "Kafka deployment completed"
}

# Function to deploy monitoring
deploy_monitoring() {
    print_status "Deploying monitoring components..."
    
    kubectl apply -f monitoring.yaml
    
    print_status "Waiting for monitoring pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=kafka-exporter --timeout=120s
    
    print_success "Monitoring deployment completed"
}

# Function to deploy security policies
deploy_security() {
    print_status "Deploying security policies..."
    
    kubectl apply -f security.yaml
    
    print_success "Security policies deployed"
}

# Function to deploy AKHQ management UI
deploy_akhq() {
    print_status "Deploying AKHQ management UI..."
    
    kubectl apply -f akhq-production.yaml
    
    print_status "Waiting for AKHQ to be ready..."
    kubectl wait --for=condition=ready pod -l app=akhq --timeout=120s
    
    print_success "AKHQ deployment completed"
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    echo ""
    print_status "Checking pod status:"
    kubectl get pods -l app=zookeeper
    kubectl get pods -l app=kafka
    kubectl get pods -l app=kafka-exporter
    kubectl get pods -l app=akhq
    
    echo ""
    print_status "Checking services:"
    kubectl get services -l app=zookeeper
    kubectl get services -l app=kafka
    kubectl get services -l app=akhq
    
    echo ""
    print_status "Checking persistent volumes:"
    kubectl get pvc
    
    echo ""
    print_status "Checking network policies:"
    kubectl get networkpolicies
    
    print_success "Deployment verification completed"
}

# Function to display access information
display_access_info() {
    print_status "Deployment completed successfully!"
    echo ""
    print_status "Access Information:"
    echo ""
    
    # Get cluster IP or external IP
    KAFKA_SERVICE_IP=$(kubectl get service kafka-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")
    AKHQ_SERVICE_IP=$(kubectl get service akhq-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "N/A")
    
    echo "Kafka External Access:"
    echo "  - Service: kafka-service"
    echo "  - Port: 9093"
    echo "  - NodePort: 30093"
    if [ "$KAFKA_SERVICE_IP" != "N/A" ]; then
        echo "  - External IP: $KAFKA_SERVICE_IP"
    fi
    echo ""
    
    echo "AKHQ Management UI:"
    echo "  - Service: akhq-service"
    echo "  - Port: 8080"
    echo "  - NodePort: 30080"
    if [ "$AKHQ_SERVICE_IP" != "N/A" ]; then
        echo "  - External IP: $AKHQ_SERVICE_IP"
    fi
    echo ""
    
    echo "Useful Commands:"
    echo "  - Check cluster status: kubectl get pods -l app=kafka"
    echo "  - View Kafka logs: kubectl logs kafka-0 -c kafka"
    echo "  - View Zookeeper logs: kubectl logs zookeeper-0 -c zookeeper"
    echo "  - Access AKHQ UI: http://<node-ip>:30080"
    echo ""
    
    print_warning "Remember to:"
    echo "  - Configure your Kafka clients to use the external endpoints"
    echo "  - Set up monitoring dashboards in Grafana"
    echo "  - Configure authentication and SSL for production use"
    echo "  - Set up regular backups"
}

# Main deployment function
main() {
    echo "=============================================================================="
    echo "KAFKA & ZOOKEEPER PRODUCTION DEPLOYMENT"
    echo "=============================================================================="
    echo ""
    
    # Check if user wants to proceed
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
    
    # Run deployment steps
    check_prerequisites
    deploy_zookeeper
    deploy_kafka
    deploy_monitoring
    deploy_security
    deploy_akhq
    verify_deployment
    display_access_info
    
    print_success "Production deployment completed successfully!"
}

# Run main function
main "$@"
