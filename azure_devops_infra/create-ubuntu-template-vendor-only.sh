#!/bin/bash

# Ubuntu Noble Proxmox Template Creation Script - SIMPLE APPROACH
# Creates a basic template with ckenimer user only
# Additional users and packages can be added via post-clone script

# Configuration
VMID=2000
TEMPLATE_NAME="ubuntu-noble-template"
STORAGE="local-zfs"
UBUNTU_IMAGE="noble-server-cloudimg-amd64.img"
MEMORY=2048
CORES=2
DISK_SIZE="20G"

echo "🚀 Creating Ubuntu Noble Template (ID: $VMID) - SIMPLE APPROACH"

# Check if snippets directory exists and create if needed
if [ ! -d "/var/lib/vz/snippets" ]; then
    echo "📁 Creating snippets directory..."
    mkdir -p /var/lib/vz/snippets
fi

# Enable snippets support (you may need to do this manually in the web UI)
echo "⚠️  Make sure 'snippets' is enabled in Datacenter > Storage > local > Edit > Content"

# Download Ubuntu cloud image if it doesn't exist
if [ ! -f "/var/lib/vz/template/iso/$UBUNTU_IMAGE" ]; then
    echo "📥 Downloading Ubuntu Noble cloud image..."
    cd /var/lib/vz/template/iso/
    wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
fi

# Resize the image
echo "💾 Resizing cloud image to $DISK_SIZE..."
qemu-img resize /var/lib/vz/template/iso/$UBUNTU_IMAGE $DISK_SIZE

# Delete existing VM/template if it exists
echo "🗑️  Removing existing template if it exists..."
qm destroy $VMID --purge 2>/dev/null || true

# Create the VM
echo "🏗️  Creating VM..."
qm create $VMID \
    --name "$TEMPLATE_NAME" \
    --ostype l26 \
    --memory $MEMORY \
    --agent 1 \
    --bios ovmf \
    --machine q35 \
    --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host \
    --socket 1 \
    --cores $CORES \
    --vga std \
    --serial0 socket \
    --net0 virtio,bridge=vmbr0

# Configure hardware
echo "⚙️  Configuring hardware..."
qm importdisk $VMID /var/lib/vz/template/iso/$UBUNTU_IMAGE $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=virtio0
qm set $VMID --scsi1 $STORAGE:cloudinit

# Generate SSH keypair for azure_runner (for post-clone use)
echo "🔑 Generating SSH keypair for azure_runner (saved for later use)..."
rm -f /tmp/azure_runner_key /tmp/azure_runner_key.pub
ssh-keygen -t ed25519 -f /tmp/azure_runner_key -N "" -C "azure_runner@proxmox-template"
AZURE_RUNNER_PUBKEY=$(cat /tmp/azure_runner_key.pub)

# Create simple cloud-init snippet for ckenimer user only
echo "📝 Creating simple cloud-init snippet..."
cat > /var/lib/vz/snippets/ubuntu-simple.yaml << EOF
#cloud-config
hostname: ubuntu-vm
manage_etc_hosts: true
ssh_pwauth: true
disable_root: false
package_update: true
packages:
  - qemu-guest-agent
  - curl
  - wget
  - vim
  - git
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - systemctl enable ssh
  - systemctl start ssh
  - echo "Template ready for post-clone configuration" > /var/log/template-ready.log
EOF

# Configure CloudInit with ckenimer user only
echo "☁️  Configuring CloudInit with ckenimer user..."
qm set $VMID --cicustom "vendor=local:snippets/ubuntu-simple.yaml"
qm set $VMID --tags ubuntu-template,24.04,simple
qm set $VMID --ciuser ckenimer
# Use a file for SSH keys to avoid shell escaping issues
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEm9ZDnP9/JuTLQHPpIDNqoBFEcSJbTUQKNm30FoBW2 ckenimer@titan.mars.local' > /tmp/ckenimer_ssh_key.pub
qm set $VMID --sshkeys /tmp/ckenimer_ssh_key.pub
qm set $VMID --searchdomain local
qm set $VMID --nameserver 8.8.8.8
qm set $VMID --ipconfig0 ip=dhcp

# Convert to template
echo "🎯 Converting VM to template..."
qm template $VMID

# Save both keys for later use
echo "💾 Saving SSH keys for later use..."
cp /tmp/azure_runner_key /root/azure_runner_private_key
chmod 600 /root/azure_runner_private_key
echo "$AZURE_RUNNER_PUBKEY" > /root/azure_runner_public_key

echo ""
echo "✅ Ubuntu Noble template created successfully!"
echo "📋 Template Details:"
echo "   Template ID: $VMID"
echo "   Template Name: $TEMPLATE_NAME"
echo "   Storage: $STORAGE"
echo ""
echo "🔧 Simple Configuration Approach:"
echo "   - Template has ckenimer user with SSH key access"
echo "   - Basic packages installed (qemu-guest-agent, curl, wget, vim, git)"
echo "   - Use post-clone script to add additional users/packages"
echo ""
echo "👤 Template User:"
echo "   - ckenimer (SSH key: your ed25519 key)"
echo ""
echo "🔐 Authentication:"
echo "   SSH Key Authentication: ENABLED"
echo "   Password Authentication: ENABLED"
echo ""
echo "🔑 Private key for azure_runner saved to: /root/azure_runner_private_key"
echo "🚀 You can now clone VMs from this template starting with ID 2001+"
echo ""
echo "📝 To test:"
echo "   qm clone $VMID 2018 --name test-vendor-only"
echo "   qm start 2018"
echo "   # Wait for boot and reboot to complete"
echo "   ssh ckenimer@VM_IP"
echo "   ssh azure_runner@VM_IP -i /root/azure_runner_private_key"
