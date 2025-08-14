# 🔧 Version Compatibility Guide

## 📋 **Required Versions for Success**

This guide ensures you use compatible versions of all components to avoid deployment failures and runtime issues.

### 🐳 **Docker Requirements**

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **Docker Engine** | 20.10.0 | 24.0.0+ | Required for container runtime |
| **Docker Compose** | 2.0.0 | 2.20.0+ | For local development |

**Installation Commands:**
```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Update Docker (Ubuntu/Debian)
sudo apt update && sudo apt upgrade docker.io docker-compose

# Update Docker (macOS)
brew upgrade docker docker-compose
```

### ☸️ **Kubernetes Requirements**

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **Kubernetes** | 1.24.0 | 1.28.0+ | Core cluster version |
| **kubectl** | 1.24.0 | 1.28.0+ | Must match cluster version |
| **minikube** | 1.28.0 | 1.32.0+ | For local development |
| **Docker Desktop** | 4.15.0 | 4.25.0+ | Includes Kubernetes |

**Version Check Commands:**
```bash
# Check kubectl version
kubectl version --client --short

# Check cluster version
kubectl version --short

# Check minikube version
minikube version

# Check Docker Desktop Kubernetes version
kubectl get nodes -o wide
```

### 🐘 **Kafka Requirements**

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **Kafka** | 3.4.0 | 3.6.0+ | Core Kafka version |
| **Confluent Platform** | 7.4.0 | 7.6.0+ | Enterprise distribution |
| **Kafka Exporter** | 1.7.0 | 1.8.0+ | Metrics collection |

**Container Images Used:**
```yaml
# In kafka-production.yaml
image: confluentinc/cp-kafka:7.6.0

# In monitoring.yaml
image: danielqsj/kafka-exporter:v1.8.0
```

### 🦒 **Zookeeper Requirements**

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **Zookeeper** | 3.8.0 | 3.9.0+ | Core Zookeeper version |
| **Confluent Zookeeper** | 7.4.0 | 7.6.0+ | Confluent distribution |

**Container Images Used:**
```yaml
# In zookeeper-production.yaml
image: confluentinc/cp-zookeeper:7.6.0
```

### 📊 **Monitoring Requirements**

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **Prometheus** | 2.45.0 | 2.48.0+ | Metrics collection |
| **Prometheus Operator** | 0.65.0 | 0.68.0+ | CRD management |
| **Grafana** | 9.5.0 | 10.2.0+ | Visualization |

### 🖥️ **Management UI Requirements**

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|-------------------|-------|
| **AKHQ** | 0.24.0 | 0.26.0+ | Kafka management UI |

**Container Images Used:**
```yaml
# In akhq-production.yaml
image: tchiotludo/akhq:0.26.0
```

## ⚠️ **Version Conflict Scenarios**

### 🚨 **Critical Version Conflicts**

#### **1. Kubernetes API Version Mismatch**
```bash
# ❌ ERROR: This will fail on older clusters
error: unable to recognize "": no matches for kind "PodDisruptionBudget" in version "policy/v1"

# ✅ SOLUTION: Use compatible API version
apiVersion: policy/v1  # For Kubernetes 1.21+
# OR
apiVersion: policy/v1beta1  # For Kubernetes 1.17-1.20
```

#### **2. Storage Class Version Issues**
```bash
# ❌ ERROR: Storage class not found
error: storageclass.storage.k8s.io "fast-ssd" not found

# ✅ SOLUTION: Check available storage classes
kubectl get storageclass
# Use available storage class in YAML files
```

#### **3. Container Runtime Version Mismatch**
```bash
# ❌ ERROR: Container runtime not supported
error: failed to create containerd task: OCI runtime create failed

# ✅ SOLUTION: Update Docker/containerd
docker --version
# Ensure Docker 20.10+ or containerd 1.6+
```

### 🔍 **Common Version-Related Errors**

#### **Error 1: Pod Security Policy Deprecated**
```bash
# ❌ ERROR: PSP is deprecated in 1.21+
error: the server doesn't have a resource type "PodSecurityPolicy"

# ✅ SOLUTION: Use Pod Security Standards
# See namespace-config.yaml for PSS labels
```

#### **Error 2: Ingress API Version Mismatch**
```bash
# ❌ ERROR: Old Ingress API
error: no matches for kind "Ingress" in version "extensions/v1beta1"

# ✅ SOLUTION: Use networking.k8s.io/v1
apiVersion: networking.k8s.io/v1
kind: Ingress
```

#### **Error 3: CRD Version Incompatibility**
```bash
# ❌ ERROR: ServiceMonitor not found
error: no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"

# ✅ SOLUTION: Install Prometheus Operator first
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
```

## 🛠️ **Version Compatibility Matrix**

### **Kubernetes 1.24-1.25 (Recommended)**
| Component | Compatible Versions |
|-----------|-------------------|
| Kafka | 3.4.0 - 3.6.0 |
| Zookeeper | 3.8.0 - 3.9.0 |
| Confluent Platform | 7.4.0 - 7.6.0 |
| Prometheus | 2.45.0 - 2.48.0 |
| AKHQ | 0.24.0 - 0.26.0 |

### **Kubernetes 1.26-1.27 (Latest)**
| Component | Compatible Versions |
|-----------|-------------------|
| Kafka | 3.5.0 - 3.6.0 |
| Zookeeper | 3.8.0 - 3.9.0 |
| Confluent Platform | 7.5.0 - 7.6.0 |
| Prometheus | 2.46.0 - 2.48.0 |
| AKHQ | 0.25.0 - 0.26.0 |

### **Kubernetes 1.28+ (Cutting Edge)**
| Component | Compatible Versions |
|-----------|-------------------|
| Kafka | 3.6.0+ |
| Zookeeper | 3.9.0+ |
| Confluent Platform | 7.6.0+ |
| Prometheus | 2.48.0+ |
| AKHQ | 0.26.0+ |

## 🔧 **Version Update Procedures**

### **Updating Kafka/Zookeeper**
```bash
# 1. Check current versions
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'

# 2. Update image versions in YAML files
# Change: confluentinc/cp-kafka:7.4.0
# To: confluentinc/cp-kafka:7.6.0

# 3. Apply updates
kubectl apply -f kafka-production.yaml
kubectl apply -f zookeeper-production.yaml

# 4. Verify updates
kubectl get pods -o wide
```

### **Updating Kubernetes**
```bash
# 1. Check current version
kubectl version --short

# 2. Update kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 3. Update minikube
minikube update-check
minikube upgrade

# 4. Verify update
kubectl version --client --short
```

### **Updating Docker**
```bash
# 1. Check current version
docker --version

# 2. Update Docker (Ubuntu)
sudo apt update
sudo apt install docker.io

# 3. Update Docker (macOS)
brew upgrade docker

# 4. Verify update
docker --version
```

## 🧪 **Version Testing Checklist**

### **Pre-Deployment Checks**
- [ ] Docker version ≥ 20.10.0
- [ ] Kubernetes version ≥ 1.24.0
- [ ] kubectl version matches cluster
- [ ] Storage classes available
- [ ] Resource quotas configured

### **Post-Deployment Verification**
- [ ] All pods running with correct images
- [ ] Services accessible on expected ports
- [ ] Persistent volumes bound
- [ ] Network policies applied
- [ ] Monitoring metrics flowing

### **Compatibility Testing**
- [ ] Kafka topic creation works
- [ ] Zookeeper ensemble healthy
- [ ] AKHQ UI accessible
- [ ] Metrics collection active
- [ ] Health checks passing

## 📚 **Version-Specific Documentation**

### **Kubernetes 1.24+**
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

### **Kafka 3.4+**
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Confluent Platform](https://docs.confluent.io/platform/current/overview.html)
- [Migration Guide](https://docs.confluent.io/platform/current/installation/upgrades/index.html)

### **Zookeeper 3.8+**
- [Zookeeper Documentation](https://zookeeper.apache.org/doc/current/)
- [Confluent Zookeeper](https://docs.confluent.io/platform/current/installation/configuration/zookeeper-config.html)

## 🚨 **Emergency Version Rollback**

### **Quick Rollback Commands**
```bash
# Rollback to previous deployment
kubectl rollout undo deployment/kafka-exporter
kubectl rollout undo statefulset/kafka
kubectl rollout undo statefulset/zookeeper

# Check rollback status
kubectl rollout status deployment/kafka-exporter
kubectl rollout status statefulset/kafka
kubectl rollout status statefulset/zookeeper

# Force rollback if needed
kubectl rollout undo deployment/kafka-exporter --to-revision=1
```

### **Image Rollback**
```bash
# Set specific image version
kubectl set image deployment/kafka-exporter kafka-exporter=danielqsj/kafka-exporter:v1.7.0

# Verify image change
kubectl get pods -o jsonpath='{.items[*].spec.containers[*].image}'
```

## 📞 **Support and Troubleshooting**

### **Version Issues Help**
- **GitHub Issues**: Check existing issues for your version
- **Stack Overflow**: Search for version-specific errors
- **Community Forums**: Confluent Community, Kubernetes Slack

### **Version Compatibility Tools**
```bash
# Check API compatibility
kubectl explain PodDisruptionBudget

# Validate YAML against cluster
kubectl apply --dry-run=client -f your-file.yaml

# Check resource availability
kubectl api-resources --verbs=list
```

---

**Remember**: Always test version updates in a non-production environment first! 🧪

**Last Updated**: December 2024  
**Maintained by**: Pradeep Kushwah (kushwahpradeep531@gmail.com)
