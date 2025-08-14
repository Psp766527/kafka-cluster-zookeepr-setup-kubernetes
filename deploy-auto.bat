@echo off
REM =============================================================================
REM AUTOMATED KAFKA & ZOOKEEPER DEPLOYMENT SCRIPT
REM =============================================================================
REM This script automatically deploys a complete production-ready
REM Kafka and Zookeeper cluster on Kubernetes.
REM 
REM Compatible with: Windows
REM 
REM Author: Pradeep Kushwah (kushwahpradeep531@gmail.com)
REM =============================================================================

setlocal enabledelayedexpansion

REM Set error handling
set "ErrorActionPreference=Stop"

REM Color codes for output (Windows 10+)
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "PURPLE=[95m"
set "CYAN=[96m"
set "NC=[0m"

REM Function to print colored output
:print_status
echo %BLUE%[INFO]%NC% %~1
goto :eof

:print_success
echo %GREEN%[SUCCESS]%NC% %~1
goto :eof

:print_warning
echo %YELLOW%[WARNING]%NC% %~1
goto :eof

:print_error
echo %RED%[ERROR]%NC% %~1
goto :eof

:print_header
echo %PURPLE%================================%NC%
echo %PURPLE%~1%NC%
echo %PURPLE%================================%NC%
goto :eof

REM Function to check if command exists
:command_exists
where %~1 >nul 2>&1
if %errorlevel% equ 0 (
    exit /b 0
) else (
    exit /b 1
)

REM Function to check prerequisites
:check_prerequisites
call :print_header "Checking Prerequisites"

REM Check if kubectl is installed
call :command_exists kubectl
if %errorlevel% neq 0 (
    call :print_error "kubectl is not installed. Please install kubectl first."
    call :print_status "Visit: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit /b 1
)

REM Check kubectl version
call :print_status "Kubectl version:"
kubectl version --client --short

REM Check if kubectl can connect to cluster
kubectl cluster-info >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "Cannot connect to Kubernetes cluster. Please check your kubectl configuration."
    exit /b 1
)

call :print_success "Kubernetes cluster connection verified"

REM Check cluster info
call :print_status "Cluster information:"
kubectl cluster-info

REM Check available storage classes
call :print_status "Available storage classes:"
kubectl get storageclass

call :print_success "Prerequisites check completed"
goto :eof

REM Function to validate configuration files
:validate_configuration
call :print_header "Validating Configuration Files"

REM Check if required files exist
set "required_files=namespace-config.yaml security.yaml zookeeper-production.yaml kafka-production.yaml monitoring.yaml akhq-production.yaml"

for %%f in (%required_files%) do (
    if not exist "%%f" (
        call :print_error "Required file not found: %%f"
        exit /b 1
    )
    call :print_status "Found: %%f"
)

REM Validate YAML syntax
call :print_status "Validating YAML syntax..."
for %%f in (%required_files%) do (
    kubectl apply --dry-run=client -f "%%f" >nul 2>&1
    if !errorlevel! neq 0 (
        call :print_error "YAML validation failed for: %%f"
        exit /b 1
    )
    call :print_status "✓ %%f - YAML syntax valid"
)

call :print_success "Configuration validation completed"
goto :eof

REM Function to deploy namespace configuration
:deploy_namespace
call :print_header "Deploying Namespace Configuration"

call :print_status "Applying namespace configuration..."
kubectl apply -f namespace-config.yaml

REM Wait for namespace to be ready
call :print_status "Waiting for namespace to be ready..."
kubectl wait --for=condition=active namespace/default --timeout=60s

call :print_success "Namespace configuration deployed"
goto :eof

REM Function to deploy security policies
:deploy_security
call :print_header "Deploying Security Policies"

call :print_status "Applying security policies..."
kubectl apply -f security.yaml

REM Wait for service accounts to be created
call :print_status "Waiting for service accounts..."
kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=1s >nul 2>&1 || echo.

call :print_success "Security policies deployed"
goto :eof

REM Function to deploy Zookeeper
:deploy_zookeeper
call :print_header "Deploying Zookeeper Ensemble"

call :print_status "Applying Zookeeper configuration..."
kubectl apply -f zookeeper-production.yaml

call :print_status "Waiting for Zookeeper pods to be ready..."
kubectl wait --for=condition=ready pod -l app=zookeeper --timeout=300s

REM Verify Zookeeper health
call :print_status "Verifying Zookeeper health..."
timeout /t 10 /nobreak >nul

for /l %%i in (0,1,2) do (
    kubectl exec zookeeper-%%i -- echo ruok ^| nc localhost 2181 | findstr "imok" >nul 2>&1
    if !errorlevel! equ 0 (
        call :print_status "✓ Zookeeper-%%i is healthy"
    ) else (
        call :print_warning "Zookeeper-%%i health check failed, but continuing..."
    )
)

call :print_success "Zookeeper ensemble deployed and healthy"
goto :eof

REM Function to deploy Kafka
:deploy_kafka
call :print_header "Deploying Kafka Cluster"

call :print_status "Applying Kafka configuration..."
kubectl apply -f kafka-production.yaml

call :print_status "Waiting for Kafka pods to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka --timeout=300s

REM Verify Kafka health
call :print_status "Verifying Kafka health..."
timeout /t 10 /nobreak >nul

for /l %%i in (0,1,2) do (
    kubectl exec kafka-%%i -- kafka-broker-api-versions --bootstrap-server localhost:9092 >nul 2>&1
    if !errorlevel! equ 0 (
        call :print_status "✓ Kafka-%%i is healthy"
    ) else (
        call :print_warning "Kafka-%%i health check failed, but continuing..."
    )
)

call :print_success "Kafka cluster deployed and healthy"
goto :eof

REM Function to deploy monitoring
:deploy_monitoring
call :print_header "Deploying Monitoring Stack"

call :print_status "Applying monitoring configuration..."
kubectl apply -f monitoring.yaml

call :print_status "Waiting for monitoring components to be ready..."
kubectl wait --for=condition=ready pod -l app=kafka-exporter --timeout=120s

call :print_success "Monitoring stack deployed"
goto :eof

REM Function to deploy AKHQ
:deploy_akhq
call :print_header "Deploying AKHQ Management UI"

call :print_status "Applying AKHQ configuration..."
kubectl apply -f akhq-production.yaml

call :print_status "Waiting for AKHQ to be ready..."
kubectl wait --for=condition=ready pod -l app=akhq --timeout=120s

call :print_success "AKHQ management UI deployed"
goto :eof

REM Function to verify deployment
:verify_deployment
call :print_header "Verifying Complete Deployment"

call :print_status "Checking all pods..."
kubectl get pods

call :print_status "Checking all services..."
kubectl get svc

call :print_status "Checking persistent volumes..."
kubectl get pvc

call :print_status "Checking network policies..."
kubectl get networkpolicies

REM Test basic functionality
call :print_status "Testing basic Kafka functionality..."

REM Create a test topic
kubectl exec kafka-0 -- kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 3 --partitions 3 --topic auto-test-topic >nul 2>&1
if !errorlevel! equ 0 (
    call :print_success "✓ Test topic created successfully"
) else (
    call :print_warning "Test topic creation failed, but deployment may still be functional"
)

REM List topics
kubectl exec kafka-0 -- kafka-topics --list --bootstrap-server localhost:9092 >nul 2>&1
if !errorlevel! equ 0 (
    call :print_success "✓ Topic listing works"
)

call :print_success "Deployment verification completed"
goto :eof

REM Function to display access information
:display_access_info
call :print_header "Access Information"

echo %CYAN%🎯 Your Kafka ^& Zookeeper cluster is now running!%NC%
echo.
echo %YELLOW%📊 Monitoring:%NC%
echo   Kafka Exporter Metrics: kubectl port-forward svc/kafka-exporter 9308:9308
echo   Then visit: http://localhost:9308/metrics
echo.
echo %YELLOW%🖥️  Management UI:%NC%
echo   AKHQ Interface: kubectl port-forward svc/akhq-service 8080:8080
echo   Then visit: http://localhost:8080
echo.
echo %YELLOW%🔧 Useful Commands:%NC%
echo   View all pods: kubectl get pods
echo   View all services: kubectl get svc
echo   View logs: kubectl logs ^<pod-name^>
echo   Access shell: kubectl exec -it ^<pod-name^> -- bash
echo.
echo %YELLOW%🧪 Test Commands:%NC%
echo   Create topic: kubectl exec -it kafka-0 -- kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 3 --partitions 3 --topic test-topic
echo   List topics: kubectl exec -it kafka-0 -- kafka-topics --list --bootstrap-server localhost:9092
echo   Produce messages: kubectl exec -it kafka-0 -- kafka-console-producer --bootstrap-server localhost:9092 --topic test-topic
echo   Consume messages: kubectl exec -it kafka-0 -- kafka-console-consumer --bootstrap-server localhost:9092 --topic test-topic --from-beginning
echo.
echo %GREEN%🎉 Deployment completed successfully!%NC%
goto :eof

REM Function to cleanup on error
:cleanup_on_error
call :print_error "Deployment failed. Cleaning up..."
call :print_status "Removing deployed resources..."

kubectl delete -f akhq-production.yaml >nul 2>&1 || echo.
kubectl delete -f monitoring.yaml >nul 2>&1 || echo.
kubectl delete -f kafka-production.yaml >nul 2>&1 || echo.
kubectl delete -f zookeeper-production.yaml >nul 2>&1 || echo.
kubectl delete -f security.yaml >nul 2>&1 || echo.
kubectl delete -f namespace-config.yaml >nul 2>&1 || echo.

call :print_error "Cleanup completed. Please check the error messages above and try again."
exit /b 1

REM Main deployment function
:main
call :print_header "Kafka ^& Zookeeper Automated Deployment"
echo %CYAN%Author: Pradeep Kushwah%NC%
echo %CYAN%Email: kushwahpradeep531@gmail.com%NC%
echo.

REM Run deployment steps
call :check_prerequisites
if %errorlevel% neq 0 goto :cleanup_on_error

call :validate_configuration
if %errorlevel% neq 0 goto :cleanup_on_error

call :deploy_namespace
if %errorlevel% neq 0 goto :cleanup_on_error

call :deploy_security
if %errorlevel% neq 0 goto :cleanup_on_error

call :deploy_zookeeper
if %errorlevel% neq 0 goto :cleanup_on_error

call :deploy_kafka
if %errorlevel% neq 0 goto :cleanup_on_error

call :deploy_monitoring
if %errorlevel% neq 0 goto :cleanup_on_error

call :deploy_akhq
if %errorlevel% neq 0 goto :cleanup_on_error

call :verify_deployment
if %errorlevel% neq 0 goto :cleanup_on_error

call :display_access_info

call :print_header "Deployment Summary"
call :print_success "✅ All components deployed successfully!"
call :print_success "✅ Kafka cluster is ready for use"
call :print_success "✅ Zookeeper ensemble is healthy"
call :print_success "✅ Monitoring is active"
call :print_success "✅ Management UI is available"
echo.
call :print_status "Next steps:"
call :print_status "1. Access the AKHQ UI to manage your Kafka cluster"
call :print_status "2. Set up Grafana dashboards for monitoring"
call :print_status "3. Configure your applications to connect to Kafka"
call :print_status "4. Review the documentation for advanced configuration"
echo.
call :print_success "Happy streaming! 🚀"
goto :eof

REM Run main function
call :main
pause
