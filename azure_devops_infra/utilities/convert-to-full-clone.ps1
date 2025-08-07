# Convert Linked Clones to Full Clones
# This script converts existing linked clone VMs to full clones
# Run this BEFORE deleting the template to avoid data loss

param(
    [Parameter(Mandatory=$true)]
    [int[]]$VmIds,
    
    [string]$ProxmoxHost = "10.155.10.130",
    [string]$Username = "root"
)

Write-Host "🔄 Converting VMs to full clones..." -ForegroundColor Cyan

foreach ($VmId in $VmIds) {
    Write-Host "   🔧 Converting VM $VmId..." -ForegroundColor White
    
    # Stop the VM first
    Write-Host "      Stopping VM $VmId..."
    ssh $Username@$ProxmoxHost "qm stop $VmId" 2>$null
    
    # Wait for VM to stop
    Start-Sleep -Seconds 10
    
    # Move/copy the disk to break the chain
    Write-Host "      Converting disk to full clone..."
    ssh $Username@$ProxmoxHost "qm move-disk $VmId virtio0 --storage local-zfs --format raw" | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✅ VM $VmId converted successfully" -ForegroundColor Green
        
        # Start the VM again
        Write-Host "      Starting VM $VmId..."
        ssh $Username@$ProxmoxHost "qm start $VmId"
    } else {
        Write-Host "      ❌ Failed to convert VM $VmId" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "🎉 Conversion process completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Notes:" -ForegroundColor Yellow
Write-Host "   - VMs are now independent of the template"
Write-Host "   - Safe to delete template after verification"
Write-Host "   - Full clones use more storage space"
