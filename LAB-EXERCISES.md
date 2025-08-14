# 🧪 Lab Exercises for Kafka & Zookeeper

## 🎯 Learning Objectives

These hands-on exercises will help you understand:
- How Kafka and Zookeeper work together
- Kubernetes StatefulSet behavior
- Data persistence and replication
- Monitoring and observability
- Troubleshooting common issues

## 🚀 Exercise 1: Understanding StatefulSets

### Objective
Learn how StatefulSets create pods in order and maintain stable identities.

### Steps:
1. **Deploy Zookeeper only:**
   ```bash
   kubectl apply -f zookeeper-production.yaml
   ```

2. **Watch the deployment process:**
   ```bash
   kubectl get pods -l app=zookeeper -w
   ```

3. **Observe the pattern:**
   - Notice how `zookeeper-0` starts first
   - Then `zookeeper-1` starts after `zookeeper-0` is ready
   - Finally `zookeeper-2` starts

4. **Check the DNS names:**
   ```bash
   # Test DNS resolution
   kubectl exec -it zookeeper-0 -- nslookup zookeeper-1.zookeeper-headless
   kubectl exec -it zookeeper-0 -- nslookup zookeeper-2.zookeeper-headless
   ```

### Questions to Answer:
- Why do pods start in order?
- What happens if you delete `zookeeper-1`?
- How does the headless service help with DNS resolution?

---

## 🚀 Exercise 2: Testing Fault Tolerance

### Objective
Understand how the cluster handles failures and maintains quorum.

### Steps:
1. **Ensure Zookeeper is running:**
   ```bash
   kubectl get pods -l app=zookeeper
   ```

2. **Test quorum with 3 nodes:**
   ```bash
   kubectl exec -it zookeeper-0 -- echo stat | nc localhost 2181
   ```

3. **Delete one Zookeeper pod:**
   ```bash
   kubectl delete pod zookeeper-1
   ```

4. **Watch it restart:**
   ```bash
   kubectl get pods -l app=zookeeper -w
   ```

5. **Test quorum with 2 nodes:**
   ```bash
   kubectl exec -it zookeeper-0 -- echo stat | nc localhost 2181
   ```

6. **Delete another pod (breaking quorum):**
   ```bash
   kubectl delete pod zookeeper-2
   ```

7. **Observe what happens:**
   ```bash
   kubectl exec -it zookeeper-0 -- echo stat | nc localhost 2181
   ```

### Questions to Answer:
- What happens when you have 2 out of 3 nodes?
- What happens when you have only 1 out of 3 nodes?
- Why is an odd number of nodes important for quorum?

---

## 🚀 Exercise 3: Understanding Data Persistence

### Objective
Learn how persistent volumes work and why they're important.

### Steps:
1. **Deploy Kafka:**
   ```bash
   kubectl apply -f kafka-production.yaml
   ```

2. **Wait for Kafka to be ready:**
   ```bash
   kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s
   ```

3. **Create a test topic:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-topics --create \
     --bootstrap-server localhost:9092 \
     --replication-factor 3 \
     --partitions 3 \
     --topic persistence-test
   ```

4. **Produce some messages:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-console-producer \
     --bootstrap-server localhost:9092 \
     --topic persistence-test
   ```
   
   Type these messages:
   ```
   Hello World
   This is a test
   Data persistence is important
   ```
   
   Press Ctrl+C to exit

5. **Verify messages were stored:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic persistence-test \
     --from-beginning
   ```

6. **Delete the Kafka pod:**
   ```bash
   kubectl delete pod kafka-0
   ```

7. **Wait for it to restart:**
   ```bash
   kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s
   ```

8. **Check if data is still there:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic persistence-test \
     --from-beginning
   ```

### Questions to Answer:
- Why did the data survive the pod restart?
- What would happen without persistent storage?
- How does replication factor 3 protect your data?

---

## 🚀 Exercise 4: Exploring Monitoring

### Objective
Understand how monitoring works and what metrics are available.

### Steps:
1. **Deploy monitoring:**
   ```bash
   kubectl apply -f monitoring.yaml
   ```

2. **Wait for Kafka Exporter to be ready:**
   ```bash
   kubectl wait --for=condition=ready pod -l app=kafka-exporter --timeout=120s
   ```

3. **Port forward to Kafka Exporter:**
   ```bash
   kubectl port-forward svc/kafka-exporter 9308:9308
   ```

4. **Visit the metrics endpoint:**
   - Open your browser to `http://localhost:9308/metrics`
   - Look for Kafka-related metrics

5. **Find specific metrics:**
   - Search for "kafka_topic_partitions"
   - Search for "kafka_consumer_lag"
   - Search for "kafka_broker_info"

6. **Create more data to see metrics change:**
   ```bash
   # In another terminal, produce more messages
   kubectl exec -it kafka-0 -- kafka-console-producer \
     --bootstrap-server localhost:9092 \
     --topic persistence-test
   ```

7. **Refresh the metrics page to see changes**

### Questions to Answer:
- What types of metrics does Kafka Exporter provide?
- How often are metrics updated?
- What would you monitor in production?

---

## 🚀 Exercise 5: Testing Network Policies

### Objective
Understand how network policies control communication between pods.

### Steps:
1. **Check current network policies:**
   ```bash
   kubectl get networkpolicies
   ```

2. **Test communication from Kafka to Zookeeper:**
   ```bash
   kubectl exec -it kafka-0 -- nc -zv zookeeper-0.zookeeper-headless 2181
   ```

3. **Test communication from Zookeeper to Kafka:**
   ```bash
   kubectl exec -it zookeeper-0 -- nc -zv kafka-0.kafka-headless 9092
   ```

4. **Try to connect to a blocked port:**
   ```bash
   kubectl exec -it kafka-0 -- nc -zv zookeeper-0.zookeeper-headless 2888
   ```

5. **Check network policy details:**
   ```bash
   kubectl describe networkpolicy kafka-network-policy
   kubectl describe networkpolicy zookeeper-network-policy
   ```

### Questions to Answer:
- Why can Kafka connect to Zookeeper on port 2181?
- Why can't Kafka connect to Zookeeper on port 2888?
- How do network policies improve security?

---

## 🚀 Exercise 6: Scaling the Cluster

### Objective
Learn how to scale Kafka and understand the implications.

### Steps:
1. **Check current Kafka deployment:**
   ```bash
   kubectl get statefulset kafka
   kubectl get pods -l app=kafka
   ```

2. **Scale Kafka to 5 brokers:**
   ```bash
   kubectl scale statefulset kafka --replicas=5
   ```

3. **Watch the new brokers start:**
   ```bash
   kubectl get pods -l app=kafka -w
   ```

4. **Check the new broker IDs:**
   ```bash
   kubectl exec -it kafka-3 -- echo $KAFKA_BROKER_ID
   kubectl exec -it kafka-4 -- echo $KAFKA_BROKER_ID
   ```

5. **Create a topic with higher replication:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-topics --create \
     --bootstrap-server localhost:9092 \
     --replication-factor 5 \
     --partitions 3 \
     --topic scale-test
   ```

6. **Describe the topic to see replication:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-topics --describe \
     --bootstrap-server localhost:9092 \
     --topic scale-test
   ```

### Questions to Answer:
- What broker IDs did the new pods get?
- Can you create a topic with replication factor 6?
- What are the benefits of more brokers?

---

## 🚀 Exercise 7: Understanding Health Checks

### Objective
Learn how health checks work and when they're used.

### Steps:
1. **Check the health check configuration:**
   ```bash
   kubectl get pod kafka-0 -o yaml | grep -A 20 readinessProbe
   kubectl get pod kafka-0 -o yaml | grep -A 20 livenessProbe
   ```

2. **Test the readiness probe manually:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-broker-api-versions --bootstrap-server localhost:9092
   ```

3. **Check Zookeeper health check:**
   ```bash
   kubectl exec -it zookeeper-0 -- echo ruok | nc localhost 2181
   ```

4. **Simulate a health check failure:**
   ```bash
   # This is just for learning - don't do this in production!
   kubectl exec -it kafka-0 -- pkill -f kafka
   ```

5. **Watch what happens:**
   ```bash
   kubectl get pods -l app=kafka -w
   ```

6. **Check the events:**
   ```bash
   kubectl describe pod kafka-0
   ```

### Questions to Answer:
- What's the difference between readiness and liveness probes?
- When would you use each type of probe?
- How do health checks help with high availability?

---

## 🚀 Exercise 8: Troubleshooting Practice

### Objective
Practice troubleshooting common issues in a safe environment.

### Steps:
1. **Create a problem (intentionally):**
   ```bash
   # Delete a Zookeeper pod
   kubectl delete pod zookeeper-0
   ```

2. **Observe the symptoms:**
   ```bash
   kubectl get pods -l app=zookeeper
   kubectl get pods -l app=kafka
   ```

3. **Investigate the issue:**
   ```bash
   # Check pod events
   kubectl describe pod zookeeper-0
   
   # Check pod logs
   kubectl logs zookeeper-0 -c zookeeper
   
   # Check init container logs
   kubectl logs zookeeper-0 -c set-myid
   ```

4. **Check related resources:**
   ```bash
   kubectl get pvc
   kubectl get events --sort-by='.lastTimestamp'
   ```

5. **Fix the issue:**
   ```bash
   # Wait for the pod to restart automatically
   kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s
   ```

### Questions to Answer:
- What symptoms indicated the problem?
- What resources did you check to diagnose the issue?
- How did Kubernetes automatically recover?

---

## 🚀 Exercise 9: Performance Testing

### Objective
Understand how the cluster performs under load.

### Steps:
1. **Create a performance test topic:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-topics --create \
     --bootstrap-server localhost:9092 \
     --replication-factor 3 \
     --partitions 10 \
     --topic performance-test
   ```

2. **Run a simple performance test:**
   ```bash
   # In one terminal, start a consumer
   kubectl exec -it kafka-0 -- kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic performance-test \
     --from-beginning
   ```

3. **In another terminal, produce messages:**
   ```bash
   kubectl exec -it kafka-0 -- kafka-console-producer \
     --bootstrap-server localhost:9092 \
     --topic performance-test
   ```

4. **Monitor resource usage:**
   ```bash
   kubectl top pods -l app=kafka
   kubectl top pods -l app=zookeeper
   ```

5. **Check metrics during load:**
   - Visit the Kafka Exporter metrics page
   - Look for changes in throughput metrics

### Questions to Answer:
- How does the cluster handle increased load?
- What metrics would you monitor in production?
- How would you optimize performance?

---

## 🚀 Exercise 10: Cleanup and Reflection

### Objective
Clean up resources and reflect on what you've learned.

### Steps:
1. **Remove all resources:**
   ```bash
   kubectl delete -f akhq-production.yaml
   kubectl delete -f monitoring.yaml
   kubectl delete -f kafka-production.yaml
   kubectl delete -f zookeeper-production.yaml
   kubectl delete -f security.yaml
   kubectl delete -f namespace-config.yaml
   ```

2. **Remove persistent volumes:**
   ```bash
   kubectl delete pvc --all
   ```

3. **Verify cleanup:**
   ```bash
   kubectl get all
   kubectl get pvc
   ```

### Reflection Questions:
- What was the most challenging concept to understand?
- How did hands-on practice help your understanding?
- What would you do differently next time?
- What questions do you still have?

---

## 🎓 Additional Challenges

### Challenge 1: Multi-Namespace Deployment
- Deploy Kafka in one namespace and Zookeeper in another
- Configure cross-namespace communication
- Understand namespace isolation

### Challenge 2: Custom Configuration
- Modify Kafka configuration for different use cases
- Adjust Zookeeper ensemble size
- Test different resource limits

### Challenge 3: Backup and Recovery
- Implement a backup strategy for your data
- Test recovery procedures
- Document disaster recovery steps

### Challenge 4: Security Hardening
- Enable SSL/TLS encryption
- Implement authentication
- Add authorization policies

---

## 🏆 Success Criteria

You've successfully completed these exercises when you can:
- ✅ Deploy a working Kafka and Zookeeper cluster
- ✅ Explain how StatefulSets work
- ✅ Understand data persistence and replication
- ✅ Monitor cluster health and performance
- ✅ Troubleshoot common issues
- ✅ Scale the cluster up and down
- ✅ Clean up resources properly

## 🎉 Congratulations!

You've completed a comprehensive hands-on learning experience with Kafka and Zookeeper on Kubernetes! This knowledge will serve you well in real-world scenarios.

**Remember:** The best way to learn is by doing. Keep experimenting, breaking things, and fixing them. Every failure is a learning opportunity! 🚀

---

## 👨‍💻 Developer

**Pradeep Kushwah**  
📧 Email: kushwahpradeep531@gmail.com

These lab exercises were designed to provide hands-on learning experience with Kafka and Zookeeper on Kubernetes.
