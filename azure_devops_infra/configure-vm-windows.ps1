# Windows Configuration Script for Proxmox VMs
# Run this FROM WINDOWS after VM is created on Proxmox
# This script handles all VM configuration via SSH

param(
    [Parameter(Mandatory=$true)]
    [string]$VmIp,
    
    [Parameter(Mandatory=$false)]
    [string]$Hostname,
    
    [string]$SshUser = "ckenimer",
    [int]$SshTimeout = 300,
    [int]$RetryDelay = 10
)

Write-Host "🔧 Configuring VM at $VmIp with hostname $Hostname..." -ForegroundColor Cyan

# Function to test SSH connectivity
function Test-SshConnection {
    param([string]$IpAddress, [string]$User)
    
    try {
        $result = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$User@$IpAddress" "echo 'connected'" 2>$null
        return $result -eq "connected"
    }
    catch {
        return $false
    }
}

# Wait for SSH to be available
Write-Host "⏳ Waiting for SSH connectivity..."
$startTime = Get-Date
$timeout = $SshTimeout

while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($timeout)) {
    if (Test-SshConnection -IpAddress $VmIp -User $SshUser) {
        Write-Host "✅ SSH connection established!" -ForegroundColor Green
        break
    }
    
    Write-Host "⏳ SSH not ready, retrying in $RetryDelay seconds..."
    Start-Sleep -Seconds $RetryDelay
}

# Final connectivity check
if (-not (Test-SshConnection -IpAddress $VmIp -User $SshUser)) {
    Write-Host "❌ Failed to establish SSH connection within $timeout seconds" -ForegroundColor Red
    exit 1
}

Write-Host "🔧 Starting VM configuration..."

# Configure hostname if provided
if ($Hostname) {
    Write-Host "🏷️  Setting hostname to $Hostname..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo hostnamectl set-hostname $Hostname"
}

# Update /etc/hosts
Write-Host "📝 Updating /etc/hosts..."
$hostsEntry = "127.0.1.1`t$Hostname"
ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "echo '$hostsEntry' | sudo tee -a /etc/hosts"

# Update system packages
Write-Host "📦 Updating system packages..."
ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo apt update && sudo apt upgrade -y"

# Install additional packages if needed
Write-Host "📦 Installing additional packages..."
ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo apt install -y htop tree neofetch"

# Configure timezone
Write-Host "🌍 Setting timezone..."
ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo timedatectl set-timezone America/New_York"

# Configure automatic updates
Write-Host "🔄 Configuring automatic updates..."
ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo systemctl enable unattended-upgrades"

# Get system info
Write-Host "📊 Getting system information..."
$systemInfo = ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "neofetch --stdout" 2>$null

# Create SSH key for azure_runner user if it doesn't exist
if (-not (Test-Path "azure_runner_private_key")) {
    Write-Host "🔑 Generating SSH key for azure_runner..."
    ssh-keygen -t ed25519 -f azure_runner_private_key -N "" -C "azure_runner@vm"
    Write-Host "   ✅ SSH key generated: azure_runner_private_key"
} else {
    Write-Host "   ✅ SSH key already exists: azure_runner_private_key"
}

# add azure_runner user if not exists, add SSH key
Write-Host "👤 Checking for azure_runner user..."
$azureRunnerExists = ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "id -u azure_runner" 2>$null

if (-not $azureRunnerExists) {
    Write-Host "   ➕ User azure_runner does not exist, creating..."
    
    # Read the public key content
    $publicKeyContent = Get-Content "azure_runner_private_key.pub" -Raw
    $publicKeyContent = $publicKeyContent.Trim()
    
    # Execute setup commands one by one for better error handling
    Write-Host "   📝 Creating user and setting up groups..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo useradd -m -s /bin/bash azure_runner 2>/dev/null || echo 'User already exists'"
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo usermod -aG sudo azure_runner"
    
    Write-Host "   🔐 Setting up SSH directory and permissions..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo mkdir -p /home/azure_runner/.ssh"
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo chmod 700 /home/azure_runner/.ssh"
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo touch /home/azure_runner/.ssh/authorized_keys"
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo chmod 600 /home/azure_runner/.ssh/authorized_keys"
    
    Write-Host "   🔑 Adding SSH public key..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "echo '$publicKeyContent' | sudo tee /home/azure_runner/.ssh/authorized_keys > /dev/null"
    
    Write-Host "   👤 Setting correct ownership..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo chown -R azure_runner:azure_runner /home/azure_runner/.ssh"
    
    Write-Host "   🔧 Configuring sudo access..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "echo 'azure_runner ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/azure_runner > /dev/null"
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo chmod 440 /etc/sudoers.d/azure_runner"
    
    Write-Host "   🔒 Disabling password authentication..."
    ssh -o StrictHostKeyChecking=no "$SshUser@$VmIp" "sudo usermod --lock azure_runner"
    
    Write-Host "   🔑 Testing SSH key authentication for azure_runner..."
    $testResult = ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i "azure_runner_private_key" "azure_runner@$VmIp" "echo 'SSH key works'" 2>$null
    
    if ($testResult -eq "SSH key works") {
        Write-Host "   ✅ SSH key authentication working for azure_runner" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  SSH key test failed - you may need to troubleshoot manually" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "   ✅ User azure_runner already exists"
    Write-Host "   🔑 Testing existing SSH key authentication..."
    $testResult = ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no -i "azure_runner_private_key" "azure_runner@$VmIp" "echo 'SSH key works'" 2>$null
    
    if ($testResult -eq "SSH key works") {
        Write-Host "   ✅ SSH key authentication working for azure_runner" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  SSH key authentication not working - may need manual setup" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "🎉 VM configuration completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 VM Details:" -ForegroundColor Yellow
Write-Host "   IP Address: $VmIp"
Write-Host "   Hostname: $Hostname"
Write-Host "   SSH User: $SshUser"
Write-Host ""
Write-Host "📊 System Information:" -ForegroundColor Yellow
Write-Host $systemInfo
Write-Host ""
Write-Host "🔗 Connection Commands:" -ForegroundColor Yellow
Write-Host "   Primary user: ssh $SshUser@$VmIp"
Write-Host "   Azure runner: ssh -i azure_runner_private_key azure_runner@$VmIp"
Write-Host ""
Write-Host "📝 Notes:" -ForegroundColor Cyan
Write-Host "   - The azure_runner user has passwordless sudo access"
Write-Host "   - SSH key authentication is required (password login disabled)"
Write-Host "   - Private key file: azure_runner_private_key"
