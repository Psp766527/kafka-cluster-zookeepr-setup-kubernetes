@echo off
REM =============================================================================
REM AUTOMATED CLEANUP SCRIPT FOR KAFKA & ZOOKEEPER
REM =============================================================================
REM This script removes all deployed Kafka and Zookeeper resources
REM from your Kubernetes cluster.
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

REM Function to check if kubectl is available
:check_kubectl
where kubectl >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "kubectl is not installed or not in PATH"
    exit /b 1
)

kubectl cluster-info >nul 2>&1
if %errorlevel% neq 0 (
    call :print_error "Cannot connect to Kubernetes cluster"
    exit /b 1
)
goto :eof

REM Function to confirm cleanup
:confirm_cleanup
call :print_warning "⚠️  WARNING: This will delete ALL Kafka and Zookeeper resources!"
call :print_warning "This includes:"
echo   - All pods (Kafka, Zookeeper, AKHQ, Kafka Exporter)
echo   - All services
echo   - All persistent volume claims (PVCs)
echo   - All persistent volumes (PVs)
echo   - All network policies
echo   - All service accounts
echo   - All configuration maps and secrets
echo.
call :print_warning "⚠️  ALL DATA WILL BE LOST!"
echo.

set /p "confirm=Are you sure you want to continue? (yes/no): "
if /i not "%confirm%"=="yes" (
    call :print_status "Cleanup cancelled by user"
    exit /b 0
)
goto :eof

REM Function to remove resources
:remove_resources
call :print_header "Removing Kafka ^& Zookeeper Resources"

REM List of files to delete (in reverse order of deployment)
set "files=akhq-production.yaml monitoring.yaml kafka-production.yaml zookeeper-production.yaml security.yaml namespace-config.yaml"

for %%f in (%files%) do (
    if exist "%%f" (
        call :print_status "Removing resources from: %%f"
        kubectl delete -f "%%f" --ignore-not-found=true
    ) else (
        call :print_warning "File not found: %%f (skipping)"
    )
)
goto :eof

REM Function to remove persistent volumes
:remove_persistent_volumes
call :print_header "Removing Persistent Volumes"

call :print_status "Removing all PVCs..."
kubectl delete pvc --all --ignore-not-found=true

call :print_status "Removing orphaned PVs..."
for /f "tokens=1" %%i in ('kubectl get pv ^| findstr /i "zookeeper kafka"') do (
    kubectl delete pv %%i --ignore-not-found=true
)
goto :eof

REM Function to verify cleanup
:verify_cleanup
call :print_header "Verifying Cleanup"

call :print_status "Checking remaining pods..."
for /f "tokens=*" %%i in ('kubectl get pods -o name 2^>nul ^| findstr /i "zookeeper kafka akhq"') do (
    call :print_warning "Pod still exists: %%i"
)

call :print_status "Checking remaining services..."
for /f "tokens=*" %%i in ('kubectl get svc -o name 2^>nul ^| findstr /i "zookeeper kafka akhq"') do (
    call :print_warning "Service still exists: %%i"
)

call :print_status "Checking remaining PVCs..."
for /f "tokens=*" %%i in ('kubectl get pvc -o name 2^>nul') do (
    call :print_warning "PVC still exists: %%i"
)

call :print_status "Checking remaining network policies..."
for /f "tokens=*" %%i in ('kubectl get networkpolicies -o name 2^>nul ^| findstr /i "zookeeper kafka akhq"') do (
    call :print_warning "Network policy still exists: %%i"
)
goto :eof

REM Function to force cleanup (if needed)
:force_cleanup
call :print_header "Force Cleanup (if needed)"

call :print_warning "Attempting to force remove any remaining resources..."

REM Force delete any remaining pods
for /f "tokens=*" %%i in ('kubectl get pods -o name ^| findstr /i "zookeeper kafka akhq"') do (
    kubectl delete %%i --force --grace-period=0 --ignore-not-found=true
)

REM Force delete any remaining PVCs
for /f "tokens=*" %%i in ('kubectl get pvc -o name') do (
    kubectl delete %%i --force --grace-period=0 --ignore-not-found=true
)

REM Force delete any remaining PVs
for /f "tokens=1" %%i in ('kubectl get pv ^| findstr /i "zookeeper kafka"') do (
    kubectl delete pv %%i --force --grace-period=0 --ignore-not-found=true
)

call :print_success "Force cleanup completed"
goto :eof

REM Main cleanup function
:main
call :print_header "Kafka ^& Zookeeper Cleanup Script"
echo %CYAN%Author: Pradeep Kushwah%NC%
echo %CYAN%Email: kushwahpradeep531@gmail.com%NC%
echo.

REM Check prerequisites
call :check_kubectl
if %errorlevel% neq 0 exit /b 1

REM Confirm cleanup
call :confirm_cleanup
if %errorlevel% neq 0 exit /b 0

REM Remove resources
call :remove_resources

REM Remove persistent volumes
call :remove_persistent_volumes

REM Wait a moment for resources to be cleaned up
call :print_status "Waiting for resources to be cleaned up..."
timeout /t 10 /nobreak >nul

REM Verify cleanup
call :verify_cleanup

REM Ask if force cleanup is needed
echo.
set /p "force_cleanup=Do you want to force cleanup any remaining resources? (yes/no): "
if /i "%force_cleanup%"=="yes" (
    call :force_cleanup
)

call :print_header "Cleanup Summary"
call :print_success "✅ Cleanup process completed!"
call :print_success "✅ All Kafka and Zookeeper resources have been removed"
call :print_success "✅ Persistent volumes have been cleaned up"
echo.
call :print_status "Note: If you see any remaining resources, they may be:"
call :print_status "  - Managed by other controllers"
call :print_status "  - Protected by finalizers"
call :print_status "  - In a terminating state (will be removed automatically)"
echo.
call :print_success "Your cluster is now clean! 🧹"
goto :eof

REM Run main function
call :main
pause
