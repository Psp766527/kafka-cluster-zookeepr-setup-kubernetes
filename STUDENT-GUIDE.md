# 🎓 Student Deployment Guide

## 🚀 Your First Kafka & Zookeeper Deployment

This guide will walk you through deploying your first production-ready Kafka and Zookeeper cluster on Kubernetes. We'll go step by step, explaining what each command does and why it's important.

## 📋 Before We Start

### What You Need:
- A Kubernetes cluster (minikube, Docker Desktop, or cloud-based)
- `kubectl` command-line tool
- Basic understanding of Kubernetes concepts

### What We'll Build:
- **3-node Zookeeper ensemble** for cluster coordination
- **3-broker Kafka cluster** for data streaming
- **Monitoring stack** with Prometheus and Kafka Exporter
- **Management UI** with AKHQ for easy administration
- **Security policies** for production safety

## 🎯 Step 1: Understanding Your Cluster

First, let's see what we're working with:

```bash
# Check if kubectl is working
kubectl version --client

# Check your cluster
kubectl cluster-info

# See what's currently running
kubectl get all
```

**What This Does:**
- `kubectl version` - Shows your kubectl version
- `kubectl cluster-info` - Shows your cluster details
- `kubectl get all` - Shows all resources in the default namespace

**Expected Output:**
```
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   1d
```

## 🎯 Step 2: Validate Your Configuration

Before deploying, let's make sure everything is correct:

```bash
# Make the validation script executable
chmod +x validate-config.sh

# Run the validation
./validate-config.sh
```

**What This Does:**
- Checks YAML syntax for all files
- Verifies security configurations
- Looks for common issues
- Provides recommendations

**If You See Errors:**
- Fix any YAML syntax issues
- Check that all files exist
- Ensure kubectl is properly configured

## 🎯 Step 3: Deploy Step by Step

### Phase 1: Foundation (Security & Namespace)

```bash
# 1. Apply namespace configuration
kubectl apply -f namespace-config.yaml

# 2. Apply security policies
kubectl apply -f security.yaml
```

**What This Does:**
- `namespace-config.yaml` - Sets up security standards and resource limits
- `security.yaml` - Creates service accounts and network policies

**Watch What Happens:**
```bash
# Check what was created
kubectl get serviceaccounts
kubectl get networkpolicies
```

**Expected Output:**
```
NAME                    SECRETS   AGE
akhq-sa                1         5s
kafka-exporter-sa      1         5s
kafka-sa               1         5s
zookeeper-sa           1         5s
```

### Phase 2: Zookeeper Ensemble

```bash
# Deploy Zookeeper
kubectl apply -f zookeeper-production.yaml
```

**What This Does:**
- Creates 3 Zookeeper pods (zookeeper-0, zookeeper-1, zookeeper-2)
- Sets up persistent storage for each pod
- Configures the ensemble to work together

**Watch the Deployment:**
```bash
# Watch pods start up (this will take a few minutes)
kubectl get pods -l app=zookeeper -w
```

**What You'll See:**
```
NAME           READY   STATUS     RESTARTS   AGE
zookeeper-0    0/1     Pending    0          0s
zookeeper-0    0/1     Pending    0          5s
zookeeper-0    0/1     ContainerCreating   0          10s
zookeeper-0    0/1     Running             0          30s
zookeeper-0    1/1     Running             0          45s
zookeeper-1    0/1     Pending             0          45s
zookeeper-1    0/1     Pending             0          50s
zookeeper-1    0/1     ContainerCreating   0          55s
zookeeper-1    0/1     Running             0          1m15s
zookeeper-1    1/1     Running             0          1m30s
zookeeper-2    0/1     Pending             0          1m30s
zookeeper-2    0/1     Pending             0          1m35s
zookeeper-2    0/1     ContainerCreating   0          1m40s
zookeeper-2    0/1     Running             0          2m
zookeeper-2    1/1     Running             0          2m15s
```

**Why This Order?**
- StatefulSets create pods in order (0, 1, 2)
- Each pod waits for the previous one to be ready
- This ensures proper ensemble formation

**Check What Was Created:**
```bash
# See all Zookeeper resources
kubectl get all -l app=zookeeper

# Check persistent volumes
kubectl get pvc

# Check services
kubectl get svc -l app=zookeeper
```

**Test Zookeeper Health:**
```bash
# Test the first Zookeeper node
kubectl exec -it zookeeper-0 -- echo ruok | nc localhost 2181

# Expected output: imok
```

### Phase 3: Kafka Cluster

```bash
# Deploy Kafka (only after Zookeeper is ready)
kubectl apply -f kafka-production.yaml
```

**What This Does:**
- Creates 3 Kafka brokers (kafka-0, kafka-1, kafka-2)
- Each broker waits for Zookeeper to be ready
- Sets up replication factor 3 for data safety

**Watch the Deployment:**
```bash
# Watch Kafka pods start up
kubectl get pods -l app=kafka -w
```

**What You'll See:**
```
NAME      READY   STATUS     RESTARTS   AGE
kafka-0   0/1     Pending    0          0s
kafka-0   0/1     Pending    0          5s
kafka-0   0/1     Init:0/1   0          10s
kafka-0   0/1     Init:0/1   0          30s
kafka-0   0/1     Init:1/1   0          35s
kafka-0   0/1     Running    0          40s
kafka-0   1/1     Running    0          1m
```

**Why Init Containers?**
- `wait-for-zookeeper` ensures Zookeeper is ready
- This prevents Kafka from starting before dependencies are available

**Check What Was Created:**
```bash
# See all Kafka resources
kubectl get all -l app=kafka

# Check Kafka services
kubectl get svc -l app=kafka
```

**Test Kafka Health:**
```bash
# Test the first Kafka broker
kubectl exec -it kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092
```

### Phase 4: Monitoring Stack

```bash
# Deploy monitoring
kubectl apply -f monitoring.yaml
```

**What This Does:**
- Creates Prometheus ServiceMonitors for automatic discovery
- Deploys Kafka Exporter for additional metrics
- Sets up monitoring endpoints

**Check Monitoring:**
```bash
# See monitoring resources
kubectl get all -l app=kafka-exporter

# Port forward to see metrics
kubectl port-forward svc/kafka-exporter 9308:9308
```

**Then visit:** `http://localhost:9308/metrics` in your browser

### Phase 5: Management UI

```bash
# Deploy AKHQ management interface
kubectl apply -f akhq-production.yaml
```

**What This Does:**
- Creates a web-based Kafka management interface
- Allows you to create topics, view consumers, and monitor the cluster
- Provides a user-friendly way to manage Kafka

**Access the UI:**
```bash
# Port forward to AKHQ
kubectl port-forward svc/akhq-service 8080:8080
```

**Then visit:** `http://localhost:8080` in your browser

## 🎯 Step 4: Verify Your Deployment

### Check Overall Status:
```bash
# See all pods
kubectl get pods

# See all services
kubectl get svc

# See all persistent volumes
kubectl get pvc
```

**Expected Output:**
```
NAME                READY   STATUS    RESTARTS   AGE
akhq-xxx-xxx        1/1     Running   0          2m
kafka-0             1/1     Running   0          5m
kafka-1             1/1     Running   0          4m
kafka-2             1/1     Running   0          3m
kafka-exporter-xxx  1/1     Running   0          1m
zookeeper-0         1/1     Running   0          8m
zookeeper-1         1/1     Running   0          7m
zookeeper-2         1/1     Running   0          6m
```

### Test the Complete System:
```bash
# 1. Create a test topic
kubectl exec -it kafka-0 -- kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --replication-factor 3 \
  --partitions 3 \
  --topic student-test

# 2. List topics
kubectl exec -it kafka-0 -- kafka-topics --list \
  --bootstrap-server localhost:9092

# 3. Describe the topic
kubectl exec -it kafka-0 -- kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --topic student-test
```

## 🎯 Step 5: Understanding What You Built

### Zookeeper Ensemble:
- **3 nodes** working together for high availability
- **Quorum system** - 2 out of 3 must be running
- **Persistent storage** - data survives pod restarts
- **Automatic leader election** - one node becomes the leader

### Kafka Cluster:
- **3 brokers** for data replication
- **Replication factor 3** - each message is stored on 3 brokers
- **Automatic broker ID assignment** - no manual configuration needed
- **Dual listeners** - internal (9092) and external (9093)

### Monitoring:
- **Prometheus integration** - automatic metric collection
- **Kafka Exporter** - additional metrics not available from Kafka
- **Health checks** - automatic detection of problems

### Security:
- **Network policies** - restrict which pods can talk to each other
- **Service accounts** - minimal required permissions
- **Security contexts** - non-root execution

## 🎯 Step 6: Experiment and Learn

### Try These Experiments:

#### 1. Scale the Cluster:
```bash
# Scale Kafka to 5 brokers
kubectl scale statefulset kafka --replicas=5

# Watch the new brokers start
kubectl get pods -l app=kafka -w
```

#### 2. Test Fault Tolerance:
```bash
# Delete a Zookeeper pod (it will restart automatically)
kubectl delete pod zookeeper-1

# Watch it restart
kubectl get pods -l app=zookeeper -w
```

#### 3. Test Data Persistence:
```bash
# Create a topic with data
kubectl exec -it kafka-0 -- kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic student-test

# Type some messages, then press Ctrl+C

# Delete and recreate the pod
kubectl delete pod kafka-0

# Check if data is still there
kubectl exec -it kafka-0 -- kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic student-test \
  --from-beginning
```

## 🎯 Step 7: Clean Up (When Done Learning)

```bash
# Remove everything
kubectl delete -f akhq-production.yaml
kubectl delete -f monitoring.yaml
kubectl delete -f kafka-production.yaml
kubectl delete -f zookeeper-production.yaml
kubectl delete -f security.yaml
kubectl delete -f namespace-config.yaml

# Remove persistent volumes (this will delete your data!)
kubectl delete pvc --all
```

## 🎓 What You've Learned

1. **Kubernetes StatefulSets** - Managing stateful applications
2. **Distributed Systems** - How Kafka and Zookeeper work together
3. **Persistent Storage** - PVCs and data durability
4. **Security** - Network policies and security contexts
5. **Monitoring** - Prometheus integration and health checks
6. **Production Practices** - High availability and fault tolerance

## 🚀 Next Steps

### Continue Learning:
- **Kafka Streams** - Real-time stream processing
- **Kafka Connect** - Data import/export
- **Schema Registry** - Data format management
- **Kubernetes Operators** - Advanced deployment patterns

### Practice Projects:
- Build a real-time data pipeline
- Create a monitoring dashboard
- Implement backup and recovery
- Add authentication and SSL

## 🔍 Troubleshooting Tips

### If Something Goes Wrong:

1. **Check pod status**: `kubectl get pods`
2. **Check pod events**: `kubectl describe pod <pod-name>`
3. **Check pod logs**: `kubectl logs <pod-name>`
4. **Check services**: `kubectl get svc`
5. **Check persistent volumes**: `kubectl get pvc`

### Common Issues:

- **Storage class not available** - Check with `kubectl get storageclass`
- **Resource limits too low** - Check cluster capacity
- **Network policies blocking** - Check network policy configuration
- **Init containers failing** - Check dependency availability

## 🎉 Congratulations!

You've successfully deployed a production-ready Kafka and Zookeeper cluster on Kubernetes! This is a significant achievement that demonstrates understanding of:

- Distributed systems architecture
- Kubernetes resource management
- Production deployment practices
- Monitoring and observability
- Security best practices

**Keep experimenting, breaking things, and fixing them - that's how you'll truly learn!** 🚀

---

## 👨‍💻 Developer

**Pradeep Kushwah**  
📧 Email: kushwahpradeep531@gmail.com

This guide was created to help students learn Kafka and Zookeeper deployment on Kubernetes.
