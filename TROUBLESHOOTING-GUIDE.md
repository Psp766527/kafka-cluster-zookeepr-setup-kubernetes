# 🚨 Troubleshooting Guide

## 📋 **Common Student Errors & Solutions**

This guide covers the most common mistakes students make when deploying Kafka and Zookeeper on Kubernetes, along with step-by-step solutions.

## 🚨 **Critical Errors (Deployment Won't Start)**

### **Error 1: "no matches for kind" - API Version Issues**

#### **❌ What Students Do Wrong:**
```yaml
# Using deprecated API versions
apiVersion: extensions/v1beta1  # ❌ Deprecated
apiVersion: policy/v1beta1      # ❌ Deprecated in newer clusters
```

#### **✅ Solution:**
```yaml
# Use current API versions
apiVersion: networking.k8s.io/v1
apiVersion: policy/v1
```

#### **🔍 How to Check:**
```bash
# Check what API versions your cluster supports
kubectl api-resources --verbs=list

# Check specific resource availability
kubectl explain PodDisruptionBudget
```

---

### **Error 2: "storageclass not found" - Storage Issues**

#### **❌ What Students Do Wrong:**
```yaml
# Using non-existent storage class
storageClassName: "fast-ssd"  # ❌ Might not exist
storageClassName: "premium"   # ❌ Cloud-specific, might not exist
```

#### **✅ Solution:**
```bash
# 1. Check available storage classes
kubectl get storageclass

# 2. Use available storage class
storageClassName: "standard"  # ✅ Usually available
storageClassName: "gp2"       # ✅ AWS EKS default
storageClassName: "pd-standard" # ✅ GKE default
```

#### **🔍 Common Storage Classes by Platform:**
- **minikube**: `standard`
- **Docker Desktop**: `hostpath`
- **AWS EKS**: `gp2`, `gp3`
- **GKE**: `pd-standard`, `pd-ssd`
- **Azure AKS**: `managed-premium`

---

### **Error 3: "insufficient memory" - Resource Limits**

#### **❌ What Students Do Wrong:**
```yaml
# Setting resource limits too high
resources:
  requests:
    memory: "8Gi"  # ❌ Might exceed cluster capacity
    cpu: "4"       # ❌ Might exceed cluster capacity
```

#### **✅ Solution:**
```yaml
# Use reasonable resource limits
resources:
  requests:
    memory: "1Gi"   # ✅ Start small
    cpu: "500m"     # ✅ Start small
  limits:
    memory: "2Gi"   # ✅ Reasonable limit
    cpu: "1000m"    # ✅ Reasonable limit
```

#### **🔍 How to Check Cluster Capacity:**
```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check current resource usage
kubectl top nodes
kubectl top pods
```

---

## ⚠️ **Common Misconfigurations**

### **Misconfiguration 1: Wrong Service Types**

#### **❌ What Students Do Wrong:**
```yaml
# Using wrong service type for external access
apiVersion: v1
kind: Service
metadata:
  name: kafka-service
spec:
  type: ClusterIP  # ❌ No external access
  ports:
    - port: 9093
      targetPort: 9093
```

#### **✅ Solution:**
```yaml
# For external access, use NodePort or LoadBalancer
apiVersion: v1
kind: Service
metadata:
  name: kafka-service
spec:
  type: NodePort  # ✅ External access via node ports
  ports:
    - port: 9093
      targetPort: 9093
      nodePort: 30093  # ✅ Specific node port
```

---

### **Misconfiguration 2: Incorrect Port Mappings**

#### **❌ What Students Do Wrong:**
```yaml
# Wrong port mappings
ports:
  - containerPort: 9092  # ❌ Internal port
    name: external       # ❌ Misleading name
```

#### **✅ Solution:**
```yaml
# Clear port naming and mapping
ports:
  - containerPort: 9092
    name: internal      # ✅ Internal communication
  - containerPort: 9093
    name: external      # ✅ External access
```

---

### **Misconfiguration 3: Missing Health Checks**

#### **❌ What Students Do Wrong:**
```yaml
# Missing or incorrect health checks
containers:
  - name: zookeeper
    # ❌ No health checks defined
```

#### **✅ Solution:**
```yaml
# Proper health checks
containers:
  - name: zookeeper
    readinessProbe:
      exec:
        command:
          - sh
          - -c
          - "echo ruok | nc localhost 2181"
      initialDelaySeconds: 10
      periodSeconds: 10
    livenessProbe:
      exec:
        command:
          - sh
          - -c
          - "echo ruok | nc localhost 2181"
      initialDelaySeconds: 30
      periodSeconds: 30
```

---

## 🔍 **Runtime Errors (Deployment Starts But Fails)**

### **Error 1: Pods Stuck in "Pending" State**

#### **🔍 Diagnosis Commands:**
```bash
# Check pod status
kubectl get pods

# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl describe nodes

# Check storage issues
kubectl get pvc
kubectl get pv
```

#### **✅ Common Solutions:**
```bash
# 1. Check if nodes have enough resources
kubectl top nodes

# 2. Check if storage classes are available
kubectl get storageclass

# 3. Check if there are taints on nodes
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 4. Check if pods can be scheduled
kubectl get events --sort-by='.lastTimestamp'
```

---

### **Error 2: Pods Stuck in "CrashLoopBackOff"**

#### **🔍 Diagnosis Commands:**
```bash
# Check pod logs
kubectl logs <pod-name>

# Check previous container logs
kubectl logs <pod-name> --previous

# Check pod events
kubectl describe pod <pod-name>

# Check init container logs
kubectl logs <pod-name> -c <init-container-name>
```

#### **✅ Common Solutions:**
```bash
# 1. Check configuration files
kubectl apply --dry-run=client -f your-file.yaml

# 2. Check if dependencies are running
kubectl get pods -l app=zookeeper

# 3. Check if services are accessible
kubectl get svc

# 4. Check network policies
kubectl get networkpolicies
```

---

### **Error 3: Services Not Accessible**

#### **🔍 Diagnosis Commands:**
```bash
# Check service status
kubectl get svc

# Check service endpoints
kubectl get endpoints

# Check if pods are ready
kubectl get pods -l app=kafka

# Test service connectivity
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup kafka-service
```

#### **✅ Common Solutions:**
```bash
# 1. Check if pods are running and ready
kubectl get pods -l app=kafka

# 2. Check if services have endpoints
kubectl get endpoints kafka-service

# 3. Check if network policies allow traffic
kubectl describe networkpolicy

# 4. Test connectivity from within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- http://kafka-service:9092
```

---

## 🧪 **Testing & Validation Commands**

### **Pre-Deployment Testing**
```bash
# 1. Validate YAML syntax
kubectl apply --dry-run=client -f your-file.yaml

# 2. Check if resources exist
kubectl get storageclass
kubectl get nodes

# 3. Check cluster capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# 4. Check API versions
kubectl api-resources --verbs=list
```

### **Post-Deployment Testing**
```bash
# 1. Check all resources
kubectl get all

# 2. Check pod status
kubectl get pods

# 3. Check service connectivity
kubectl get svc

# 4. Check persistent volumes
kubectl get pvc
kubectl get pv

# 5. Check network policies
kubectl get networkpolicies
```

### **Functionality Testing**
```bash
# 1. Test Zookeeper health
kubectl exec -it zookeeper-0 -- echo ruok | nc localhost 2181

# 2. Test Kafka connectivity
kubectl exec -it kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092

# 3. Test topic creation
kubectl exec -it kafka-0 -- kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 3 --partitions 3 --topic test-topic

# 4. Test monitoring
kubectl port-forward svc/kafka-exporter 9308:9308
# Then visit http://localhost:9308/metrics
```

---

## 🚨 **Emergency Recovery Procedures**

### **Quick Recovery Commands**
```bash
# 1. Delete stuck pods
kubectl delete pod <pod-name> --force --grace-period=0

# 2. Restart deployments
kubectl rollout restart deployment/kafka-exporter

# 3. Scale down and up
kubectl scale statefulset kafka --replicas=0
kubectl scale statefulset kafka --replicas=3

# 4. Check events for clues
kubectl get events --sort-by='.lastTimestamp' | tail -20
```

### **Complete Reset (Nuclear Option)**
```bash
# 1. Delete all resources
kubectl delete -f . --ignore-not-found=true

# 2. Delete persistent volumes
kubectl delete pvc --all --ignore-not-found=true
kubectl delete pv --all --ignore-not-found=true

# 3. Wait for cleanup
kubectl get all

# 4. Redeploy from scratch
kubectl apply -f namespace-config.yaml
kubectl apply -f security.yaml
kubectl apply -f zookeeper-production.yaml
kubectl apply -f kafka-production.yaml
```

---

## 📚 **Common Student Mistakes Checklist**

### **❌ Configuration Mistakes**
- [ ] Using wrong API versions
- [ ] Incorrect storage class names
- [ ] Wrong service types for external access
- [ ] Missing or incorrect health checks
- [ ] Wrong port mappings
- [ ] Incorrect resource limits

### **❌ Deployment Mistakes**
- [ ] Deploying components in wrong order
- [ ] Not waiting for dependencies to be ready
- [ ] Applying YAML files multiple times
- [ ] Not checking prerequisites
- [ ] Ignoring error messages

### **❌ Testing Mistakes**
- [ ] Not validating YAML before applying
- [ ] Not checking pod status after deployment
- [ ] Not testing connectivity between components
- [ ] Not verifying persistent storage
- [ ] Not checking logs for errors

### **❌ Troubleshooting Mistakes**
- [ ] Not reading error messages carefully
- [ ] Not checking pod events
- [ ] Not examining logs
- [ ] Not using dry-run for validation
- [ ] Not checking resource availability

---

## 🆘 **Getting Help**

### **When to Ask for Help**
- ✅ You've tried all solutions in this guide
- ✅ You've checked logs and events
- ✅ You've validated your configuration
- ✅ You've checked version compatibility
- ✅ You've tested in a clean environment

### **Information to Provide When Asking for Help**
```bash
# 1. Your environment
kubectl version --short
docker --version
minikube version  # if using minikube

# 2. Current status
kubectl get all
kubectl get events --sort-by='.lastTimestamp' | tail -10

# 3. Error messages
kubectl describe pod <problem-pod>
kubectl logs <problem-pod>

# 4. Your configuration
cat your-problem-file.yaml
```

### **Helpful Resources**
- **GitHub Issues**: Check existing issues
- **Stack Overflow**: Search for similar problems
- **Kubernetes Documentation**: Official troubleshooting guides
- **Community Forums**: Confluent Community, Kubernetes Slack

---

## 🎯 **Prevention Tips**

### **Before Starting**
1. **Check versions** - Ensure all components are compatible
2. **Validate YAML** - Use dry-run to check syntax
3. **Check resources** - Ensure cluster has enough capacity
4. **Read documentation** - Understand what you're deploying

### **During Deployment**
1. **Deploy in order** - Follow dependency chain
2. **Wait for readiness** - Don't rush to next step
3. **Check status** - Monitor pod states
4. **Test connectivity** - Verify components can talk

### **After Deployment**
1. **Verify all resources** - Check pods, services, volumes
2. **Test functionality** - Create topics, send messages
3. **Monitor health** - Check logs and metrics
4. **Document issues** - Keep track of what you learned

---

**Remember**: Most errors are configuration-related. Take your time, read error messages carefully, and use the validation commands! 🧪

**Last Updated**: December 2024  
**Maintained by**: Pradeep Kushwah (kushwahpradeep531@gmail.com)
