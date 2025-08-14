#!/bin/bash

# =============================================================================
# CONFIGURATION VALIDATION SCRIPT
# =============================================================================
# This script validates the production configuration files for common issues
# and provides recommendations for deployment.
# 
# IMPORTANT NOTES:
# - Run this script before deployment to catch configuration issues
# - Fix any issues reported before proceeding with deployment
# - This script checks syntax, dependencies, and best practices
# =============================================================================

set -e

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

# Function to validate YAML syntax
validate_yaml() {
    local file=$1
    print_status "Validating YAML syntax for $file..."
    
    if kubectl apply --dry-run=client -f "$file" >/dev/null 2>&1; then
        print_success "YAML syntax is valid for $file"
        return 0
    else
        print_error "YAML syntax error in $file"
        kubectl apply --dry-run=client -f "$file" 2>&1 || true
        return 1
    fi
}

# Function to check for required tools
check_tools() {
    print_status "Checking required tools..."
    
    local tools=("kubectl" "yq")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 0 ]; then
        print_success "All required tools are available"
    else
        print_warning "Missing tools: ${missing_tools[*]}"
        print_warning "Install missing tools for full validation"
    fi
}

# Function to check storage classes
check_storage_classes() {
    print_status "Checking storage class configuration..."
    
    # Check if storage classes are configured
    local files=("zookeeper-production.yaml" "kafka-production.yaml")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            local storage_class=$(grep -A 5 "storageClassName" "$file" | grep "standard" || echo "")
            if [ -n "$storage_class" ]; then
                print_warning "Storage class is set to 'standard' in $file"
                print_warning "Consider updating to a more appropriate storage class for your cluster"
            fi
        fi
    done
}

# Function to check resource limits
check_resource_limits() {
    print_status "Checking resource limits..."
    
    local files=("zookeeper-production.yaml" "kafka-production.yaml" "akhq-production.yaml" "monitoring.yaml")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            if grep -q "resources:" "$file"; then
                print_success "Resource limits configured in $file"
            else
                print_warning "No resource limits found in $file"
            fi
        fi
    done
}

# Function to check security configurations
check_security() {
    print_status "Checking security configurations..."
    
    # Check for security contexts
    local files=("zookeeper-production.yaml" "kafka-production.yaml" "akhq-production.yaml")
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            if grep -q "securityContext:" "$file"; then
                print_success "Security contexts configured in $file"
            else
                print_warning "No security contexts found in $file"
            fi
            
            if grep -q "runAsUser:" "$file"; then
                print_success "Non-root user configured in $file"
            else
                print_warning "No user specification found in $file"
            fi
        fi
    done
    
    # Check for network policies
    if [ -f "security.yaml" ]; then
        if grep -q "NetworkPolicy" "security.yaml"; then
            print_success "Network policies configured"
        else
            print_warning "No network policies found"
        fi
    fi
}

# Function to check monitoring configuration
check_monitoring() {
    print_status "Checking monitoring configuration..."
    
    if [ -f "monitoring.yaml" ]; then
        if grep -q "ServiceMonitor" "monitoring.yaml"; then
            print_success "Prometheus ServiceMonitors configured"
        else
            print_warning "No ServiceMonitors found"
        fi
        
        if grep -q "kafka-exporter" "monitoring.yaml"; then
            print_success "Kafka Exporter configured"
        else
            print_warning "No Kafka Exporter found"
        fi
    else
        print_warning "Monitoring configuration file not found"
    fi
}

# Function to check for common issues
check_common_issues() {
    print_status "Checking for common configuration issues..."
    
    local issues_found=0
    
    # Check for hardcoded values
    if grep -r "127.0.0.1" . --include="*.yaml" >/dev/null 2>&1; then
        print_error "Found hardcoded localhost IP (127.0.0.1) - this won't work in production"
        issues_found=$((issues_found + 1))
    fi
    
    # Check for missing namespace specifications
    if grep -r "kind:" . --include="*.yaml" | grep -v "namespace:" | grep -E "(Service|Deployment|StatefulSet|NetworkPolicy)" >/dev/null 2>&1; then
        print_warning "Some resources may not have explicit namespace specifications"
    fi
    
    # Check for deprecated APIs
    if grep -r "apiVersion: policy/v1beta1" . --include="*.yaml" >/dev/null 2>&1; then
        print_error "Found deprecated API version policy/v1beta1"
        issues_found=$((issues_found + 1))
    fi
    
    if [ $issues_found -eq 0 ]; then
        print_success "No common issues found"
    else
        print_error "Found $issues_found common issues"
    fi
}

# Function to provide recommendations
provide_recommendations() {
    print_status "Providing deployment recommendations..."
    
    echo ""
    print_warning "Before deployment, consider:"
    echo "  1. Update storage classes to match your cluster"
    echo "  2. Adjust resource limits based on your workload"
    echo "  3. Configure authentication and SSL for production"
    echo "  4. Set up monitoring dashboards in Grafana"
    echo "  5. Configure backup strategies"
    echo "  6. Test in a development environment first"
    echo ""
    print_warning "For production security:"
    echo "  1. Enable SSL/TLS for all communication"
    echo "  2. Configure SASL authentication"
    echo "  3. Use secrets for sensitive data"
    echo "  4. Enable network policies"
    echo "  5. Set up proper RBAC"
    echo ""
}

# Main validation function
main() {
    echo "=============================================================================="
    echo "KAFKA & ZOOKEEPER CONFIGURATION VALIDATION"
    echo "=============================================================================="
    echo ""
    
    local validation_passed=true
    
    # Check tools
    check_tools
    
    # Validate YAML files
    local yaml_files=("zookeeper-production.yaml" "kafka-production.yaml" "akhq-production.yaml" "monitoring.yaml" "security.yaml" "namespace-config.yaml")
    
    for file in "${yaml_files[@]}"; do
        if [ -f "$file" ]; then
            if ! validate_yaml "$file"; then
                validation_passed=false
            fi
        else
            print_warning "File $file not found"
        fi
    done
    
    # Check configurations
    check_storage_classes
    check_resource_limits
    check_security
    check_monitoring
    check_common_issues
    
    # Provide recommendations
    provide_recommendations
    
    # Summary
    echo ""
    if [ "$validation_passed" = true ]; then
        print_success "Configuration validation completed successfully!"
        print_success "You can proceed with deployment after reviewing recommendations."
    else
        print_error "Configuration validation failed!"
        print_error "Please fix the issues above before proceeding with deployment."
        exit 1
    fi
}

# Run main function
main "$@"
