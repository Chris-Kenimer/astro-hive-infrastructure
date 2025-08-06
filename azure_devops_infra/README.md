# Proxmox VM Deployment with Ansible

This directory contains Ansible scripts to deploy Ubuntu virtual machines to Proxmox VE using the Ubuntu Noble Server cloud image.

## Prerequisites

1. **Proxmox VE** with API access enabled
2. **Ansible** installed with the `community.general` collection
3. **Ubuntu Noble Server cloud image** (`noble-server-cloudimg-amd64.img`) downloaded to Proxmox

## Setup

### 1. Install Required Collections

```bash
ansible-galaxy collection install -r requirements.yml
```

### 2. Download Ubuntu Cloud Image

On your Proxmox server, download the Ubuntu Noble Server cloud image:

```bash
cd /var/lib/vz/template/iso/
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

### 3. Configure Variables

Edit the following files to match your environment:

- `inventory.ini` - Update Proxmox host details
- `group_vars/all.yml` - Configure VM specifications and credentials
- `host_vars/proxmox-server.yml` - Host-specific configurations

### 4. Update Credentials

**Important**: Update the following in your configuration files:

- `proxmox_api_host` - Your Proxmox server IP
- `proxmox_api_password` - Your Proxmox root password
- `proxmox_node` - Your Proxmox node name
- `cloud_init_password` - VM user password
- `ssh_public_key` - Your SSH public key for passwordless access

## Usage

### Deploy a VM

```bash
ansible-playbook deploy-vm.yml
```

### Deploy with Custom Parameters

```bash
ansible-playbook deploy-vm.yml -e vm_id=102 -e vm_name=my-ubuntu-vm -e vm_memory=8192
```

### Deploy Multiple VMs

You can deploy multiple VMs by running the playbook multiple times with different VM IDs:

```bash
ansible-playbook deploy-vm.yml -e vm_id=101 -e vm_name=web-server
ansible-playbook deploy-vm.yml -e vm_id=102 -e vm_name=db-server
ansible-playbook deploy-vm.yml -e vm_id=103 -e vm_name=app-server
```

## Configuration Options

### VM Specifications

- `vm_id` - Unique VM ID (default: 100)
- `vm_name` - VM name (default: ubuntu-vm)
- `vm_memory` - RAM in MB (default: 2048)
- `vm_cores` - CPU cores (default: 2)
- `vm_disk_size` - Disk size (default: 20G)
- `vm_storage` - Storage pool (default: local-lvm)

### Network Configuration

- `vm_network_bridge` - Network bridge (default: vmbr0)
- `vm_network_model` - Network model (default: virtio)
- `ip_config` - IP configuration (default: dhcp)

### Cloud-init Configuration

- `cloud_init_user` - Default user (default: ubuntu)
- `cloud_init_password` - User password
- `ssh_public_key` - SSH public key for access
- `nameserver` - DNS server (default: 8.8.8.8)

## Security Notes

1. **Change default passwords** in `group_vars/all.yml`
2. **Add your SSH public key** for secure access
3. **Use Ansible Vault** for sensitive data in production:

```bash
ansible-vault encrypt group_vars/all.yml
```

## Troubleshooting

### Common Issues

1. **API Connection Failed**
   - Verify Proxmox API credentials
   - Check network connectivity to Proxmox host
   - Ensure API access is enabled in Proxmox

2. **Cloud Image Not Found**
   - Verify the Ubuntu cloud image is in `/var/lib/vz/template/iso/`
   - Check the image filename matches `ubuntu_image` variable

3. **Storage Issues**
   - Verify storage pool exists in Proxmox
   - Check available space on storage

4. **VM Creation Failed**
   - Ensure VM ID is unique
   - Check node name is correct
   - Verify sufficient resources

### Debug Mode

Run with verbose output for troubleshooting:

```bash
ansible-playbook deploy-vm.yml -vvv
```

## File Structure

```text
azure_devops_infra/
├── deploy-vm.yml              # Main playbook
├── inventory.ini              # Inventory configuration
├── ansible.cfg               # Ansible configuration
├── requirements.yml          # Required collections
├── group_vars/
│   └── all.yml               # Global variables
├── host_vars/
│   └── proxmox-server.yml    # Host-specific variables
└── README.md                 # This file
```
