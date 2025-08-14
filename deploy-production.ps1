# =============================================================================
# PRODUCTION DEPLOYMENT SCRIPT FOR KAFKA & ZOOKEEPER (PowerShell)
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

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check prerequisites
function Check-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    # Check if kubectl is available
    try {
        $null = Get-Command kubectl -ErrorAction Stop
    }
    catch {
        Write-Error "kubectl is not installed or not in PATH"
        exit 1
    }
    
    # Check if kubectl is configured
    try {
        $null = kubectl cluster-info 2>$null
    }
    catch {
        Write-Error "kubectl is not configured or cluster is not accessible"
        exit 1
    }
    
    # Check if namespace exists, create if not
    try {
        $null = kubectl get namespace default 2>$null
    }
    catch {
        Write-Warning "Default namespace not found, creating..."
        kubectl create namespace default
    }
    
    # Apply namespace configuration
    Write-Status "Applying namespace configuration..."
    kubectl apply -f namespace-config.yaml
    
    # Check available storage classes
    Write-Status "Available storage classes:"
    kubectl get storageclass
    
    Write-Success "Prerequisites check completed"
}

# Function to deploy Zookeeper
function Deploy-Zookeeper {
    Write-Status "Deploying Zookeeper ensemble..."
    
    kubectl apply -f zookeeper-production.yaml
    
    Write-Status "Waiting for Zookeeper pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s
    
    Write-Success "Zookeeper deployment completed"
}

# Function to deploy Kafka
function Deploy-Kafka {
    Write-Status "Deploying Kafka cluster..."
    
    kubectl apply -f kafka-production.yaml
    
    Write-Status "Waiting for Kafka pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s
    
    Write-Success "Kafka deployment completed"
}

# Function to deploy monitoring
function Deploy-Monitoring {
    Write-Status "Deploying monitoring components..."
    
    kubectl apply -f monitoring.yaml
    
    Write-Status "Waiting for monitoring pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=kafka-exporter --timeout=120s
    
    Write-Success "Monitoring deployment completed"
}

# Function to deploy security policies
function Deploy-Security {
    Write-Status "Deploying security policies..."
    
    kubectl apply -f security.yaml
    
    Write-Success "Security policies deployed"
}

# Function to deploy AKHQ management UI
function Deploy-AKHQ {
    Write-Status "Deploying AKHQ management UI..."
    
    kubectl apply -f akhq-production.yaml
    
    Write-Status "Waiting for AKHQ to be ready..."
    kubectl wait --for=condition=ready pod -l app=akhq --timeout=120s
    
    Write-Success "AKHQ deployment completed"
}

# Function to verify deployment
function Verify-Deployment {
    Write-Status "Verifying deployment..."
    
    Write-Host ""
    Write-Status "Checking pod status:"
    kubectl get pods -l app=zookeeper
    kubectl get pods -l app=kafka
    kubectl get pods -l app=kafka-exporter
    kubectl get pods -l app=akhq
    
    Write-Host ""
    Write-Status "Checking services:"
    kubectl get services -l app=zookeeper
    kubectl get services -l app=kafka
    kubectl get services -l app=akhq
    
    Write-Host ""
    Write-Status "Checking persistent volumes:"
    kubectl get pvc
    
    Write-Host ""
    Write-Status "Checking network policies:"
    kubectl get networkpolicies
    
    Write-Success "Deployment verification completed"
}

# Function to display access information
function Display-AccessInfo {
    Write-Status "Deployment completed successfully!"
    Write-Host ""
    Write-Status "Access Information:"
    Write-Host ""
    
    # Get cluster IP or external IP
    $KafkaServiceIP = kubectl get service kafka-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    $AKHQServiceIP = kubectl get service akhq-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    
    if (-not $KafkaServiceIP) { $KafkaServiceIP = "N/A" }
    if (-not $AKHQServiceIP) { $AKHQServiceIP = "N/A" }
    
    Write-Host "Kafka External Access:"
    Write-Host "  - Service: kafka-service"
    Write-Host "  - Port: 9093"
    Write-Host "  - NodePort: 30093"
    if ($KafkaServiceIP -ne "N/A") {
        Write-Host "  - External IP: $KafkaServiceIP"
    }
    Write-Host ""
    
    Write-Host "AKHQ Management UI:"
    Write-Host "  - Service: akhq-service"
    Write-Host "  - Port: 8080"
    Write-Host "  - NodePort: 30080"
    if ($AKHQServiceIP -ne "N/A") {
        Write-Host "  - External IP: $AKHQServiceIP"
    }
    Write-Host ""
    
    Write-Host "Useful Commands:"
    Write-Host "  - Check cluster status: kubectl get pods -l app=kafka"
    Write-Host "  - View Kafka logs: kubectl logs kafka-0 -c kafka"
    Write-Host "  - View Zookeeper logs: kubectl logs zookeeper-0 -c zookeeper"
    Write-Host "  - Access AKHQ UI: http://<node-ip>:30080"
    Write-Host ""
    
    Write-Warning "Remember to:"
    Write-Host "  - Configure your Kafka clients to use the external endpoints"
    Write-Host "  - Set up monitoring dashboards in Grafana"
    Write-Host "  - Configure authentication and SSL for production use"
    Write-Host "  - Set up regular backups"
}

# Main deployment function
function Main {
    Write-Host "=============================================================================="
    Write-Host "KAFKA & ZOOKEEPER PRODUCTION DEPLOYMENT"
    Write-Host "=============================================================================="
    Write-Host ""
    
    # Check if user wants to proceed
    $response = Read-Host "Do you want to proceed with the deployment? (y/N)"
    if ($response -notmatch "^[Yy]$") {
        Write-Warning "Deployment cancelled by user"
        exit 0
    }
    
    # Run deployment steps
    Check-Prerequisites
    Deploy-Zookeeper
    Deploy-Kafka
    Deploy-Monitoring
    Deploy-Security
    Deploy-AKHQ
    Verify-Deployment
    Display-AccessInfo
    
    Write-Success "Production deployment completed successfully!"
}

# Run main function
Main
