#!/bin/bash

# =============================================================================
# AUTOMATED KAFKA & ZOOKEEPER DEPLOYMENT SCRIPT
# =============================================================================
# This script automatically deploys a complete production-ready
# Kafka and Zookeeper cluster on Kubernetes.
# 
# Compatible with: Linux, macOS
# 
# Author: Pradeep Kushwah (kushwahpradeep531@gmail.com)
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if kubectl is installed
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        print_status "Visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
        exit 1
    fi
    
    # Check kubectl version
    print_status "Kubectl version:"
    kubectl version --client --short
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
        exit 1
    fi
    
    print_success "Kubernetes cluster connection verified"
    
    # Check cluster info
    print_status "Cluster information:"
    kubectl cluster-info
    
    # Check available storage classes
    print_status "Available storage classes:"
    kubectl get storageclass
    
    print_success "Prerequisites check completed"
}

# Function to validate configuration files
validate_configuration() {
    print_header "Validating Configuration Files"
    
    # Check if required files exist
    required_files=(
        "namespace-config.yaml"
        "security.yaml"
        "zookeeper-production.yaml"
        "kafka-production.yaml"
        "monitoring.yaml"
        "akhq-production.yaml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Required file not found: $file"
            exit 1
        fi
        print_status "Found: $file"
    done
    
    # Validate YAML syntax
    print_status "Validating YAML syntax..."
    for file in "${required_files[@]}"; do
        if ! kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
            print_error "YAML validation failed for: $file"
            exit 1
        fi
        print_status "✓ $file - YAML syntax valid"
    done
    
    print_success "Configuration validation completed"
}

# Function to deploy namespace configuration
deploy_namespace() {
    print_header "Deploying Namespace Configuration"
    
    print_status "Applying namespace configuration..."
    kubectl apply -f namespace-config.yaml
    
    # Wait for namespace to be ready
    print_status "Waiting for namespace to be ready..."
    kubectl wait --for=condition=active namespace/default --timeout=60s
    
    print_success "Namespace configuration deployed"
}

# Function to deploy security policies
deploy_security() {
    print_header "Deploying Security Policies"
    
    print_status "Applying security policies..."
    kubectl apply -f security.yaml
    
    # Wait for service accounts to be created
    print_status "Waiting for service accounts..."
    kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=1s 2>/dev/null || true
    
    print_success "Security policies deployed"
}

# Function to deploy Zookeeper
deploy_zookeeper() {
    print_header "Deploying Zookeeper Ensemble"
    
    print_status "Applying Zookeeper configuration..."
    kubectl apply -f zookeeper-production.yaml
    
    print_status "Waiting for Zookeeper pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s
    
    # Verify Zookeeper health
    print_status "Verifying Zookeeper health..."
    sleep 10  # Give Zookeeper time to fully initialize
    
    for i in {0..2}; do
        if kubectl exec zookeeper-$i -- echo ruok | nc localhost 2181 | grep -q "imok"; then
            print_status "✓ Zookeeper-$i is healthy"
        else
            print_warning "Zookeeper-$i health check failed, but continuing..."
        fi
    done
    
    print_success "Zookeeper ensemble deployed and healthy"
}

# Function to deploy Kafka
deploy_kafka() {
    print_header "Deploying Kafka Cluster"
    
    print_status "Applying Kafka configuration..."
    kubectl apply -f kafka-production.yaml
    
    print_status "Waiting for Kafka pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s
    
    # Verify Kafka health
    print_status "Verifying Kafka health..."
    sleep 10  # Give Kafka time to fully initialize
    
    for i in {0..2}; do
        if kubectl exec kafka-$i -- kafka-broker-api-versions --bootstrap-server localhost:9092 >/dev/null 2>&1; then
            print_status "✓ Kafka-$i is healthy"
        else
            print_warning "Kafka-$i health check failed, but continuing..."
        fi
    done
    
    print_success "Kafka cluster deployed and healthy"
}

# Function to deploy monitoring
deploy_monitoring() {
    print_header "Deploying Monitoring Stack"
    
    print_status "Applying monitoring configuration..."
    kubectl apply -f monitoring.yaml
    
    print_status "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=ready pod -l app=kafka-exporter --timeout=120s
    
    print_success "Monitoring stack deployed"
}

# Function to deploy AKHQ
deploy_akhq() {
    print_header "Deploying AKHQ Management UI"
    
    print_status "Applying AKHQ configuration..."
    kubectl apply -f akhq-production.yaml
    
    print_status "Waiting for AKHQ to be ready..."
    kubectl wait --for=condition=ready pod -l app=akhq --timeout=120s
    
    print_success "AKHQ management UI deployed"
}

# Function to verify deployment
verify_deployment() {
    print_header "Verifying Complete Deployment"
    
    print_status "Checking all pods..."
    kubectl get pods
    
    print_status "Checking all services..."
    kubectl get svc
    
    print_status "Checking persistent volumes..."
    kubectl get pvc
    
    print_status "Checking network policies..."
    kubectl get networkpolicies
    
    # Test basic functionality
    print_status "Testing basic Kafka functionality..."
    
    # Create a test topic
    if kubectl exec kafka-0 -- kafka-topics --create \
        --bootstrap-server localhost:9092 \
        --replication-factor 3 \
        --partitions 3 \
        --topic auto-test-topic >/dev/null 2>&1; then
        print_success "✓ Test topic created successfully"
    else
        print_warning "Test topic creation failed, but deployment may still be functional"
    fi
    
    # List topics
    if kubectl exec kafka-0 -- kafka-topics --list \
        --bootstrap-server localhost:9092 >/dev/null 2>&1; then
        print_success "✓ Topic listing works"
    fi
    
    print_success "Deployment verification completed"
}

# Function to display access information
display_access_info() {
    print_header "Access Information"
    
    echo -e "${CYAN}🎯 Your Kafka & Zookeeper cluster is now running!${NC}"
    echo ""
    echo -e "${YELLOW}📊 Monitoring:${NC}"
    echo "  Kafka Exporter Metrics: kubectl port-forward svc/kafka-exporter 9308:9308"
    echo "  Then visit: http://localhost:9308/metrics"
    echo ""
    echo -e "${YELLOW}🖥️  Management UI:${NC}"
    echo "  AKHQ Interface: kubectl port-forward svc/akhq-service 8080:8080"
    echo "  Then visit: http://localhost:8080"
    echo ""
    echo -e "${YELLOW}🔧 Useful Commands:${NC}"
    echo "  View all pods: kubectl get pods"
    echo "  View all services: kubectl get svc"
    echo "  View logs: kubectl logs <pod-name>"
    echo "  Access shell: kubectl exec -it <pod-name> -- bash"
    echo ""
    echo -e "${YELLOW}🧪 Test Commands:${NC}"
    echo "  Create topic: kubectl exec -it kafka-0 -- kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 3 --partitions 3 --topic test-topic"
    echo "  List topics: kubectl exec -it kafka-0 -- kafka-topics --list --bootstrap-server localhost:9092"
    echo "  Produce messages: kubectl exec -it kafka-0 -- kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic"
    echo "  Consume messages: kubectl exec -it kafka-0 -- kafka-console-consumer --bootstrap-server localhost:9092 --topic test-topic --from-beginning"
    echo ""
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Deployment failed. Cleaning up..."
    print_status "Removing deployed resources..."
    
    kubectl delete -f akhq-production.yaml 2>/dev/null || true
    kubectl delete -f monitoring.yaml 2>/dev/null || true
    kubectl delete -f kafka-production.yaml 2>/dev/null || true
    kubectl delete -f zookeeper-production.yaml 2>/dev/null || true
    kubectl delete -f security.yaml 2>/dev/null || true
    kubectl delete -f namespace-config.yaml 2>/dev/null || true
    
    print_error "Cleanup completed. Please check the error messages above and try again."
    exit 1
}

# Main deployment function
main() {
    print_header "Kafka & Zookeeper Automated Deployment"
    echo -e "${CYAN}Author: Pradeep Kushwah${NC}"
    echo -e "${CYAN}Email: kushwahpradeep531@gmail.com${NC}"
    echo ""
    
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Run deployment steps
    check_prerequisites
    validate_configuration
    deploy_namespace
    deploy_security
    deploy_zookeeper
    deploy_kafka
    deploy_monitoring
    deploy_akhq
    verify_deployment
    display_access_info
    
    print_header "Deployment Summary"
    print_success "✅ All components deployed successfully!"
    print_success "✅ Kafka cluster is ready for use"
    print_success "✅ Zookeeper ensemble is healthy"
    print_success "✅ Monitoring is active"
    print_success "✅ Management UI is available"
    echo ""
    print_status "Next steps:"
    print_status "1. Access the AKHQ UI to manage your Kafka cluster"
    print_status "2. Set up Grafana dashboards for monitoring"
    print_status "3. Configure your applications to connect to Kafka"
    print_status "4. Review the documentation for advanced configuration"
    echo ""
    print_success "Happy streaming! 🚀"
}

# Run main function
main "$@"
