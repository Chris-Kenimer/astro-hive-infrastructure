# Simple VM Creation Script - Windows PowerShell
# This script creates a VM on Proxmox and provides simple configuration commands

param(
    [Parameter(Mandatory=$true)]
    [int]$VmId,
    
    [Parameter(Mandatory=$true)]
    [string]$VmName,
    
    [Parameter(Mandatory=$true)]
    [string]$Hostname,
    
    [string]$ProxmoxHost = "10.155.10.130",
    [string]$Username = "root"
)

Write-Host "🚀 Creating VM $VmId ($VmName) on Proxmox" -ForegroundColor Green
Write-Host "==========================================="
Write-Host "   Proxmox Host: $ProxmoxHost" -ForegroundColor Cyan
Write-Host "   VM ID: $VmId" -ForegroundColor Cyan
Write-Host "   VM Name: $VmName" -ForegroundColor Cyan
Write-Host "   Hostname: $Hostname" -ForegroundColor Cyan

# Step 1: Create VM on Proxmox
Write-Host ""
Write-Host "📋 Step 1: Creating VM on Proxmox" -ForegroundColor Yellow
Write-Host "================================="

Write-Host "   🏗️  Cloning VM from template 2000 (full clone)..." -ForegroundColor White
ssh $Username@$ProxmoxHost "qm clone 2000 $VmId --name '$VmName' --full"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to clone VM" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ VM cloned successfully (full clone)" -ForegroundColor Green

Write-Host "   🚀 Starting VM $VmId..." -ForegroundColor White
ssh $Username@$ProxmoxHost "qm start $VmId"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start VM" -ForegroundColor Red
    exit 1
}
Write-Host "   ✅ VM started successfully" -ForegroundColor Green

Write-Host "   ⏳ Waiting for VM to boot (60 seconds)..." -ForegroundColor White
Start-Sleep -Seconds 60

Write-Host "   🔍 Getting VM IP address..." -ForegroundColor White
$attempts = 0
$maxAttempts = 12
$VmIp = $null

while ($attempts -lt $maxAttempts) {
    $vmIpResult = ssh $Username@$ProxmoxHost "qm agent $VmId network-get-interfaces 2>/dev/null | grep -o '10\.[0-9]*\.[0-9]*\.[0-9]*' | head -1"
    if ($vmIpResult -and $vmIpResult.Trim()) {
        $VmIp = $vmIpResult.Trim()
        Write-Host "   ✅ VM IP detected: $VmIp" -ForegroundColor Green
        break
    }
    
    $attempts++
    Write-Host "   ⏳ Waiting for IP address... (attempt $attempts/$maxAttempts)" -ForegroundColor White
    Start-Sleep -Seconds 10
}

if (-not $VmIp) {
    Write-Host "   ⚠️  Could not detect VM IP automatically" -ForegroundColor Yellow
    Write-Host "   🔍 Get IP manually: ssh $Username@$ProxmoxHost 'qm agent $VmId network-get-interfaces'"
    $VmIp = "<MANUAL_IP_NEEDED>"
}

# Step 2: Instructions for Windows configuration
Write-Host ""
Write-Host "🎉 VM CREATION COMPLETE!" -ForegroundColor Green
Write-Host "========================"
Write-Host ""
Write-Host "📋 VM Details:" -ForegroundColor Yellow
Write-Host "   VM ID: $VmId"
Write-Host "   VM Name: $VmName"
Write-Host "   Hostname: $Hostname"
Write-Host "   IP Address: $VmIp"
Write-Host ""
Write-Host "🔄 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Wait for VM to fully boot (2-3 more minutes)"
Write-Host "   2. Configure VM from Windows:"
if ($VmIp -ne "<MANUAL_IP_NEEDED>") {
    Write-Host "      .\configure-vm-windows.ps1 -VmIp $VmIp -Hostname $Hostname" -ForegroundColor White
} else {
    Write-Host "      .\configure-vm-windows.ps1 -VmIp <VM_IP> -Hostname $Hostname" -ForegroundColor White
}
Write-Host ""
Write-Host "🔑 SSH Commands (after configuration):" -ForegroundColor Yellow
Write-Host "   ssh ckenimer@$VmIp" -ForegroundColor White
Write-Host ""
Write-Host "🧹 To remove VM if needed:" -ForegroundColor Yellow
Write-Host "   ssh $Username@$ProxmoxHost 'qm stop $VmId && qm destroy $VmId --purge'" -ForegroundColor Cyan
