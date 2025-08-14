#!/bin/bash

# =============================================================================
# AUTOMATED CLEANUP SCRIPT FOR KAFKA & ZOOKEEPER
# =============================================================================
# This script removes all deployed Kafka and Zookeeper resources
# from your Kubernetes cluster.
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

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Function to confirm cleanup
confirm_cleanup() {
    print_warning "⚠️  WARNING: This will delete ALL Kafka and Zookeeper resources!"
    print_warning "This includes:"
    echo "  - All pods (Kafka, Zookeeper, AKHQ, Kafka Exporter)"
    echo "  - All services"
    echo "  - All persistent volume claims (PVCs)"
    echo "  - All persistent volumes (PVs)"
    echo "  - All network policies"
    echo "  - All service accounts"
    echo "  - All configuration maps and secrets"
    echo ""
    print_warning "⚠️  ALL DATA WILL BE LOST!"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cleanup cancelled by user"
        exit 0
    fi
}

# Function to remove resources
remove_resources() {
    print_header "Removing Kafka & Zookeeper Resources"
    
    # List of files to delete (in reverse order of deployment)
    files=(
        "akhq-production.yaml"
        "monitoring.yaml"
        "kafka-production.yaml"
        "zookeeper-production.yaml"
        "security.yaml"
        "namespace-config.yaml"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            print_status "Removing resources from: $file"
            kubectl delete -f "$file" --ignore-not-found=true
        else
            print_warning "File not found: $file (skipping)"
        fi
    done
}

# Function to remove persistent volumes
remove_persistent_volumes() {
    print_header "Removing Persistent Volumes"
    
    print_status "Removing all PVCs..."
    kubectl delete pvc --all --ignore-not-found=true
    
    print_status "Removing orphaned PVs..."
    kubectl get pv | grep -E "(zookeeper|kafka)" | awk '{print $1}' | xargs -r kubectl delete pv --ignore-not-found=true
}

# Function to verify cleanup
verify_cleanup() {
    print_header "Verifying Cleanup"
    
    print_status "Checking remaining pods..."
    remaining_pods=$(kubectl get pods -o name 2>/dev/null | grep -E "(zookeeper|kafka|akhq)" || true)
    if [[ -n "$remaining_pods" ]]; then
        print_warning "Some pods still exist:"
        echo "$remaining_pods"
    else
        print_success "✓ All pods removed"
    fi
    
    print_status "Checking remaining services..."
    remaining_svcs=$(kubectl get svc -o name 2>/dev/null | grep -E "(zookeeper|kafka|akhq)" || true)
    if [[ -n "$remaining_svcs" ]]; then
        print_warning "Some services still exist:"
        echo "$remaining_svcs"
    else
        print_success "✓ All services removed"
    fi
    
    print_status "Checking remaining PVCs..."
    remaining_pvcs=$(kubectl get pvc -o name 2>/dev/null || true)
    if [[ -n "$remaining_pvcs" ]]; then
        print_warning "Some PVCs still exist:"
        echo "$remaining_pvcs"
    else
        print_success "✓ All PVCs removed"
    fi
    
    print_status "Checking remaining network policies..."
    remaining_np=$(kubectl get networkpolicies -o name 2>/dev/null | grep -E "(zookeeper|kafka|akhq)" || true)
    if [[ -n "$remaining_np" ]]; then
        print_warning "Some network policies still exist:"
        echo "$remaining_np"
    else
        print_success "✓ All network policies removed"
    fi
}

# Function to force cleanup (if needed)
force_cleanup() {
    print_header "Force Cleanup (if needed)"
    
    print_warning "Attempting to force remove any remaining resources..."
    
    # Force delete any remaining pods
    kubectl get pods -o name | grep -E "(zookeeper|kafka|akhq)" | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true
    
    # Force delete any remaining PVCs
    kubectl get pvc -o name | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true
    
    # Force delete any remaining PVs
    kubectl get pv | grep -E "(zookeeper|kafka)" | awk '{print $1}' | xargs -r kubectl delete --force --grace-period=0 --ignore-not-found=true
    
    print_success "Force cleanup completed"
}

# Main cleanup function
main() {
    print_header "Kafka & Zookeeper Cleanup Script"
    echo -e "${CYAN}Author: Pradeep Kushwah${NC}"
    echo -e "${CYAN}Email: kushwahpradeep531@gmail.com${NC}"
    echo ""
    
    # Check prerequisites
    check_kubectl
    
    # Confirm cleanup
    confirm_cleanup
    
    # Remove resources
    remove_resources
    
    # Remove persistent volumes
    remove_persistent_volumes
    
    # Wait a moment for resources to be cleaned up
    print_status "Waiting for resources to be cleaned up..."
    sleep 10
    
    # Verify cleanup
    verify_cleanup
    
    # Ask if force cleanup is needed
    echo ""
    read -p "Do you want to force cleanup any remaining resources? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        force_cleanup
    fi
    
    print_header "Cleanup Summary"
    print_success "✅ Cleanup process completed!"
    print_success "✅ All Kafka and Zookeeper resources have been removed"
    print_success "✅ Persistent volumes have been cleaned up"
    echo ""
    print_status "Note: If you see any remaining resources, they may be:"
    print_status "  - Managed by other controllers"
    print_status "  - Protected by finalizers"
    print_status "  - In a terminating state (will be removed automatically)"
    echo ""
    print_success "Your cluster is now clean! 🧹"
}

# Run main function
main "$@"
