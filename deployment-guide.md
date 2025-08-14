# Kafka & Zookeeper Production Deployment Guide

## 🚨 Issues Found in Current Configuration

### Critical Issues:
1. **Duplicate StatefulSet definitions** - Multiple files define the same resources
2. **Missing persistent storage** - Zookeeper uses `emptyDir` which loses data
3. **Hardcoded NODE_IP** - Set to `127.0.0.1` which won't work in production
4. **No resource limits** - Missing CPU/memory constraints
5. **No security contexts** - Running as root user
6. **Inconsistent Zookeeper configuration** - Different separator formats used

### Security Issues:
1. **No authentication/encryption** - Plaintext communication
2. **No network policies** - Unrestricted network access
3. **No RBAC** - Missing service accounts and permissions
4. **No pod security policies** - Running with excessive privileges

## 📋 Production Deployment Steps

### 1. Prerequisites
```bash
# Ensure you have kubectl configured
kubectl cluster-info

# Check available storage classes
kubectl get storageclass

# Verify namespace exists
kubectl create namespace kafka-cluster --dry-run=client -o yaml | kubectl apply -f -
```

### 2. Deploy Zookeeper First
```bash
# Apply Zookeeper configuration
kubectl apply -f zookeeper-production.yaml

# Verify deployment
kubectl get pods -l app=zookeeper
kubectl logs zookeeper-0 -c zookeeper
```

### 3. Deploy Kafka
```bash
# Wait for Zookeeper to be ready
kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s

# Apply Kafka configuration
kubectl apply -f kafka-production.yaml

# Verify deployment
kubectl get pods -l app=kafka
kubectl logs kafka-0 -c kafka
```

### 4. Deploy Monitoring (Optional)
```bash
# Apply monitoring configuration
kubectl apply -f monitoring.yaml

# Verify monitoring deployment
kubectl get pods -l component=monitoring
```

### 5. Deploy Security Policies
```bash
# Apply security configurations
kubectl apply -f security.yaml

# Verify network policies
kubectl get networkpolicies
```

## 🔧 Configuration Customization

### Storage Configuration
Update `storageClassName` in both StatefulSets based on your cluster:
```yaml
storageClassName: "fast-ssd"  # For high-performance storage
storageClassName: "standard"  # For standard storage
```

### Resource Limits
Adjust based on your workload:
```yaml
resources:
  requests:
    memory: "2Gi"    # Increase for high-throughput
    cpu: "1000m"     # Increase for high-throughput
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

### Replication Factor
For production, ensure replication factor matches broker count:
```yaml
- name: KAFKA_DEFAULT_REPLICATION_FACTOR
  value: "3"  # Should match number of brokers
```

## 📊 Monitoring & Observability

### Key Metrics to Monitor:
- **Kafka**: Messages per second, lag, partition count
- **Zookeeper**: Connection count, latency, leader elections
- **System**: CPU, memory, disk I/O, network

### Grafana Dashboards:
- Import Kafka dashboard: `https://grafana.com/grafana/dashboards/7589`
- Import Zookeeper dashboard: `https://grafana.com/grafana/dashboards/10465`

## 🔒 Security Best Practices

### 1. Enable TLS/SSL
```yaml
- name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
  value: "INTERNAL:SSL,EXTERNAL:SSL"
```

### 2. Configure Authentication
```yaml
- name: KAFKA_SASL_ENABLED_MECHANISMS
  value: "PLAIN,SCRAM-SHA-256"
```

### 3. Use Secrets for Credentials
```bash
kubectl create secret generic kafka-secrets \
  --from-literal=username=admin \
  --from-literal=password=secure-password
```

## 🚀 Scaling Considerations

### Horizontal Scaling:
- **Kafka**: Add more brokers (update StatefulSet replicas)
- **Zookeeper**: Keep at 3 or 5 nodes (odd number for quorum)

### Vertical Scaling:
- Increase resource limits based on monitoring data
- Monitor JVM heap usage and adjust `KAFKA_HEAP_OPTS`

## 🛠️ Troubleshooting

### Common Issues:

1. **Zookeeper Connection Issues**:
```bash
kubectl exec -it zookeeper-0 -- nc -z zookeeper-1.zookeeper-headless 2181
```

2. **Kafka Broker Issues**:
```bash
kubectl exec -it kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092
```

3. **Storage Issues**:
```bash
kubectl describe pvc kafka-data-kafka-0
kubectl get events --sort-by='.lastTimestamp'
```

### Log Analysis:
```bash
# Check Zookeeper logs
kubectl logs zookeeper-0 -c zookeeper --tail=100

# Check Kafka logs
kubectl logs kafka-0 -c kafka --tail=100

# Check init container logs
kubectl logs kafka-0 -c wait-for-zookeeper
```

## 📈 Performance Tuning

### Kafka Tuning:
```yaml
- name: KAFKA_NUM_NETWORK_THREADS
  value: "8"
- name: KAFKA_NUM_IO_THREADS
  value: "8"
- name: KAFKA_SOCKET_SEND_BUFFER_BYTES
  value: "102400"
- name: KAFKA_SOCKET_RECEIVE_BUFFER_BYTES
  value: "102400"
```

### Zookeeper Tuning:
```yaml
- name: ZOOKEEPER_MAX_CLIENT_CNXNS
  value: "100"
- name: ZOOKEEPER_SYNC_LIMIT
  value: "10"
```

## 🔄 Backup & Recovery

### Backup Strategy:
1. **Topic Data**: Use Kafka's built-in replication
2. **Configuration**: Store in Git with version control
3. **Zookeeper Data**: Regular snapshots of persistent volumes

### Recovery Procedures:
1. **Broker Failure**: Automatic failover with replication
2. **Zookeeper Failure**: Quorum-based recovery
3. **Data Loss**: Restore from replicated partitions

## 📞 Support & Maintenance

### Regular Maintenance:
- Monitor disk usage and clean up old logs
- Update images regularly for security patches
- Review and adjust resource limits based on usage
- Test disaster recovery procedures

### Health Checks:
```bash
# Check cluster health
kubectl get pods -l app=kafka
kubectl get pods -l app=zookeeper

# Check services
kubectl get svc -l app=kafka
kubectl get svc -l app=zookeeper

# Check persistent volumes
kubectl get pvc
```
