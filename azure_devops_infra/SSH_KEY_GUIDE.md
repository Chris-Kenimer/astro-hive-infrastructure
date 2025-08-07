# SSH Key Management Guide

## Multiple Ways to Specify SSH Keys

### 1. Using the PowerShell Script with -SSHKey Parameter

```powershell
# Use a specific private key file
.\connect-vm.ps1 -VMName "web-server" -User "ckenimer" -IPAddress "10.155.10.200" -SSHKey "C:\Users\chris\.ssh\id_ed25519"

# Use a different key for different purposes
.\connect-vm.ps1 -VMName "web-server" -User "ckenimer" -IPAddress "10.155.10.200" -SSHKey "$env:USERPROFILE\.ssh\work_key"

# Use relative path
.\connect-vm.ps1 -VMName "web-server" -User "ckenimer" -IPAddress "10.155.10.200" -SSHKey "~/.ssh/personal_key"
```

### 2. Direct SSH Commands

```bash
# Specify key with -i flag
ssh -i ~/.ssh/id_ed25519 ckenimer@10.155.10.200
ssh -i C:\Users\chris\.ssh\work_key ckenimer@10.155.10.200
ssh -i ./azure_runner_private_key azure_runner@10.155.10.200

# Multiple options
ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 ckenimer@10.155.10.200
```

### 3. SSH Config File (~/.ssh/config)

Create or edit `C:\Users\chris\.ssh\config`:

```
# Default configuration for all Proxmox VMs
Host 10.155.10.*
    User ckenimer
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

# Specific configuration for different VM ranges
Host proxmox-vm-*
    HostName 10.155.10.%h
    User ckenimer
    IdentityFile ~/.ssh/proxmox_key
    
# Configuration for azure_runner service account
Host *-runner
    User azure_runner
    IdentityFile ./azure_runner_private_key
    
# Work VMs with specific key
Host work-*
    User ckenimer
    IdentityFile ~/.ssh/work_key
```

Then connect simply with:
```bash
ssh 10.155.10.200
ssh proxmox-vm-200
ssh web-server-runner
```

### 4. SSH Agent

Add your keys to SSH agent:

```bash
# Add multiple keys to agent
ssh-add ~/.ssh/id_ed25519
ssh-add ~/.ssh/work_key  
ssh-add ./azure_runner_private_key

# List loaded keys
ssh-add -l

# Remove all keys
ssh-add -D
```

### 5. Environment Variables

Set default key in your PowerShell profile:

```powershell
# Add to $PROFILE
$env:SSH_DEFAULT_KEY = "$env:USERPROFILE\.ssh\id_ed25519"

# Then use in scripts
ssh -i $env:SSH_DEFAULT_KEY ckenimer@10.155.10.200
```

## Common SSH Key Locations on Windows

```
C:\Users\chris\.ssh\id_rsa          # Default RSA key
C:\Users\chris\.ssh\id_ed25519      # Default Ed25519 key  
C:\Users\chris\.ssh\work_key        # Work-specific key
C:\Users\chris\.ssh\personal_key    # Personal projects key
C:\Users\chris\.ssh\github_key      # GitHub-specific key
```

## Best Practices

1. **Use SSH Config** - Most flexible, clean connection commands
2. **Key per purpose** - Work, personal, service accounts
3. **Ed25519 keys** - More secure and faster than RSA
4. **Descriptive names** - `work_ed25519`, `github_rsa`, etc.
5. **SSH Agent** - For frequently used keys

## Troubleshooting

```bash
# Debug SSH connection with verbose output
ssh -v -i ~/.ssh/id_ed25519 ckenimer@10.155.10.200

# Test which key SSH would use
ssh -T git@github.com

# Check SSH agent
ssh-add -l

# Test key file directly
ssh-keygen -l -f ~/.ssh/id_ed25519
```
