# 🚨 IMPORTANT CONFIGURATION NOTES

## Critical Settings That Must Be Configured

### 1. Storage Configuration
**⚠️ CRITICAL: Update these before deployment**

```yaml
# In zookeeper-production.yaml and kafka-production.yaml
storageClassName: "standard"  # ← CHANGE THIS
```
**Available options:**
- `standard` - Standard storage class
- `fast-ssd` - High-performance SSD storage
- `premium-ssd` - Premium SSD storage
- Check your cluster: `kubectl get storageclass`

### 2. Storage Sizes
**⚠️ CRITICAL: Adjust based on your data volume**

```yaml
# Zookeeper storage
storage: 10Gi  # ← Adjust based on metadata volume

# Kafka storage  
storage: 20Gi  # ← Adjust based on message volume
```

### 3. Resource Limits
**⚠️ CRITICAL: Adjust based on your workload**

```yaml
# Zookeeper resources
requests:
  memory: "512Mi"  # ← Minimum required
  cpu: "250m"      # ← Minimum required
limits:
  memory: "1Gi"    # ← Maximum allowed
  cpu: "500m"      # ← Maximum allowed

# Kafka resources
requests:
  memory: "1Gi"    # ← Minimum required
  cpu: "500m"      # ← Minimum required
limits:
  memory: "2Gi"    # ← Maximum allowed
  cpu: "1000m"     # ← Maximum allowed
```

### 4. Replication Factor
**⚠️ CRITICAL: Must match broker count**

```yaml
# In kafka-production.yaml
- name: KAFKA_DEFAULT_REPLICATION_FACTOR
  value: "3"  # ← Must match number of brokers (replicas: 3)
```

### 5. External Access Configuration
**⚠️ CRITICAL: Update for your environment**

```yaml
# In kafka-production.yaml
type: LoadBalancer  # ← Use NodePort for on-premise clusters
nodePort: 30093     # ← Change if port conflicts
```

## Security Settings

### 6. TLS/SSL Configuration
**⚠️ PRODUCTION: Enable for security**

```yaml
# Change from PLAINTEXT to SSL
- name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
  value: "INTERNAL:SSL,EXTERNAL:SSL"  # ← Enable SSL
```

### 7. Authentication
**⚠️ PRODUCTION: Enable for security**

```yaml
# Add authentication
- name: KAFKA_SASL_ENABLED_MECHANISMS
  value: "PLAIN,SCRAM-SHA-256"
```

## Performance Tuning

### 8. JVM Heap Settings
**⚠️ IMPORTANT: Adjust based on available memory**

```yaml
# In kafka-production.yaml
- name: KAFKA_HEAP_OPTS
  value: "-Xmx1g -Xms1g"  # ← Adjust heap size
```

### 9. Log Retention
**⚠️ IMPORTANT: Adjust based on storage and requirements**

```yaml
# Log retention settings
- name: KAFKA_LOG_RETENTION_HOURS
  value: "168"  # ← 7 days, adjust as needed
- name: KAFKA_LOG_RETENTION_BYTES
  value: "1073741824"  # ← 1GB, adjust as needed
```

## Monitoring Configuration

### 10. Prometheus Operator
**⚠️ REQUIRED: For monitoring to work**

```bash
# Check if Prometheus Operator is installed
kubectl get servicemonitors
# If not installed, install it first
```

### 11. Kafka Exporter Configuration
**⚠️ IMPORTANT: Update broker list if you change replicas**

```yaml
# In monitoring.yaml
- --kafka.server=kafka-0.kafka-headless:9092,kafka-1.kafka-headless:9092,kafka-2.kafka-headless:9092
# ← Update this list if you change the number of brokers
```

## Deployment Order

### 12. Critical Deployment Sequence
**⚠️ CRITICAL: Follow this exact order**

```bash
# 1. Deploy Zookeeper first
kubectl apply -f zookeeper-production.yaml

# 2. Wait for Zookeeper to be ready
kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s

# 3. Deploy Kafka
kubectl apply -f kafka-production.yaml

# 4. Deploy monitoring (optional)
kubectl apply -f monitoring.yaml

# 5. Deploy security policies
kubectl apply -f security.yaml
```

## Troubleshooting

### 13. Common Issues

**Zookeeper won't start:**
- Check if myid files are created correctly
- Verify ensemble configuration
- Check storage class availability

**Kafka won't start:**
- Ensure Zookeeper is running first
- Check broker ID assignment
- Verify advertised listeners configuration

**External access not working:**
- Check service type (LoadBalancer vs NodePort)
- Verify node port configuration
- Check firewall rules

### 14. Health Checks

```bash
# Check Zookeeper health
kubectl exec -it zookeeper-0 -- echo ruok | nc localhost 2181

# Check Kafka health
kubectl exec -it kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092

# Check cluster status
kubectl get pods -l app=zookeeper
kubectl get pods -l app=kafka
```

## Backup and Recovery

### 15. Data Protection

**Kafka data:**
- Use replication factor 3 for high availability
- Regular backups of persistent volumes
- Monitor disk usage

**Zookeeper data:**
- Regular snapshots of persistent volumes
- Monitor ensemble health
- Keep odd number of nodes for quorum

## Security Checklist

- [ ] Enable TLS/SSL for all communication
- [ ] Configure authentication (SASL/SCRAM)
- [ ] Use network policies to restrict access
- [ ] Run containers as non-root users
- [ ] Drop unnecessary Linux capabilities
- [ ] Use secrets for sensitive data
- [ ] Regular security updates

## Performance Checklist

- [ ] Monitor resource usage
- [ ] Adjust heap sizes based on workload
- [ ] Tune log retention settings
- [ ] Monitor disk I/O performance
- [ ] Scale horizontally if needed
- [ ] Use appropriate storage class

## Monitoring Checklist

- [ ] Prometheus Operator installed
- [ ] ServiceMonitors configured
- [ ] Kafka Exporter deployed
- [ ] Grafana dashboards imported
- [ ] Alerts configured
- [ ] Log aggregation set up
