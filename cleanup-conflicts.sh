#!/bin/bash

# =============================================================================
# CLEANUP SCRIPT FOR CONFLICTING KAFKA/ZOOKEEPER CONFIGURATIONS
# =============================================================================
# This script removes existing Kafka and Zookeeper configurations that
# conflict with the new production setup.
# 
# IMPORTANT NOTES:
# - Run this BEFORE deploying the production configuration
# - This will DELETE existing data if you choose to remove PVCs
# - Make sure you have backups if you need to preserve data
# - This script is idempotent - safe to run multiple times
# =============================================================================

# Cleanup script for conflicting Kafka/Zookeeper configurations
# Run this before deploying the production configuration

echo "🧹 Cleaning up conflicting configurations..."

# Delete existing StatefulSets
echo "Deleting existing StatefulSets..."
kubectl delete statefulset kafka --ignore-not-found=true
kubectl delete statefulset zookeeper --ignore-not-found=true

# Delete existing Services
echo "Deleting existing Services..."
kubectl delete service kafka-headless --ignore-not-found=true
kubectl delete service kafka-service --ignore-not-found=true
kubectl delete service zookeeper-headless --ignore-not-found=true
kubectl delete service zookeeper-service --ignore-not-found=true

# Delete existing PVCs (WARNING: This will delete data)
echo "⚠️  WARNING: Deleting Persistent Volume Claims will delete all data!"
echo "   If you have important data, make sure to backup before proceeding."
read -p "Do you want to delete PVCs? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting PVCs..."
    kubectl delete pvc --selector=app=kafka --ignore-not-found=true
    kubectl delete pvc --selector=app=zookeeper --ignore-not-found=true
    echo "✅ PVCs deleted successfully"
else
    echo "Skipping PVC deletion. You may need to manually clean up orphaned PVCs."
    echo "   To manually delete PVCs later, run:"
    echo "   kubectl delete pvc --selector=app=kafka"
    echo "   kubectl delete pvc --selector=app=zookeeper"
fi

# Delete any remaining pods
echo "Deleting any remaining pods..."
kubectl delete pods --selector=app=kafka --ignore-not-found=true
kubectl delete pods --selector=app=zookeeper --ignore-not-found=true

# Wait for cleanup to complete
echo "Waiting for cleanup to complete..."
kubectl wait --for=delete pod --selector=app=kafka --timeout=60s --ignore-not-found=true
kubectl wait --for=delete pod --selector=app=zookeeper --timeout=60s --ignore-not-found=true

echo "✅ Cleanup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Review the production configuration files:"
echo "   - zookeeper-production.yaml"
echo "   - kafka-production.yaml"
echo "   - monitoring.yaml"
echo "   - security.yaml"
echo ""
echo "2. Follow the deployment guide in deployment-guide.md"
echo ""
echo "3. Deploy in order:"
echo "   kubectl apply -f zookeeper-production.yaml"
echo "   kubectl apply -f kafka-production.yaml"
echo "   kubectl apply -f monitoring.yaml"
echo "   kubectl apply -f security.yaml"
echo ""
echo "🔍 To verify deployment:"
echo "   kubectl get pods -l app=zookeeper"
echo "   kubectl get pods -l app=kafka"
echo "   kubectl get services -l app=zookeeper"
echo "   kubectl get services -l app=kafka"
