#!/usr/bin/env bash
# Permanent setup: bind NVIDIA GPU to vfio-pci for VM passthrough.
# Run with: sudo bash setup_vfio_passthrough.sh
# After reboot, the host will not use the NVIDIA GPU; add both PCI devices to the VM.

set -e
[[ $(id -u) -eq 0 ]] || { echo "Run with sudo."; exit 1; }

echo "=== Creating /etc/modprobe.d/vfio.conf ==="
cat > /etc/modprobe.d/vfio.conf << 'EOF'
# Bind NVIDIA GPU (01:00.0) and its audio (01:00.1) to vfio-pci
options vfio-pci ids=10de:24b6,10de:228b
EOF

echo "=== Blacklisting nvidia and nouveau (so vfio-pci can claim the GPU) ==="
cat > /etc/modprobe.d/blacklist-nvidia-passthrough.conf << 'EOF'
# Do not load nvidia/nouveau so vfio-pci can own the GPU for VM passthrough
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist nouveau
EOF

echo "=== Removing softdep file (blacklist makes it unnecessary) ==="
rm -f /etc/modprobe.d/nvidia-vfio.conf

echo "=== Adding kernel cmdline blacklist (enforced at boot) ==="
if [[ -f /etc/default/grub ]]; then
  # Add modprobe.blacklist to GRUB_CMDLINE_LINUX_DEFAULT if not already there
  if grep -q 'modprobe.blacklist=nvidia' /etc/default/grub; then
    echo "Kernel blacklist already in GRUB."
  else
    sed -i.bak 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 modprobe.blacklist=nvidia,nvidiafb,nvidia_drm,nouveau"/' /etc/default/grub
    echo "Added modprobe.blacklist to GRUB."
  fi
  update-grub 2>/dev/null || true
fi

echo "=== Removing nvidia from initramfs modules (if present) ==="
for mod in nvidia nvidiafb nvidia_drm nouveau; do
  sed -i.bak "/^${mod}$/d" /etc/initramfs-tools/modules 2>/dev/null || true
done

echo "=== Disabling initramfs hook that loads nvidia (framebuffer-nvidia) ==="
if [[ -f /usr/share/initramfs-tools/hooks/framebuffer-nvidia ]]; then
  mv /usr/share/initramfs-tools/hooks/framebuffer-nvidia /usr/share/initramfs-tools/hooks/framebuffer-nvidia.disabled
  echo "Renamed framebuffer-nvidia to framebuffer-nvidia.disabled"
fi

echo "=== Adding vfio modules to initramfs ==="
for mod in vfio_pci vfio vfio_iommu_type1; do
  grep -q "^${mod}$" /etc/initramfs-tools/modules 2>/dev/null || echo "$mod" >> /etc/initramfs-tools/modules
done

echo "=== Updating initramfs ==="
update-initramfs -u

echo ""
echo "Done. Reboot for changes to take effect: sudo reboot"
echo "After reboot, check with: lspci -k -s 01:00.0   (should show 'vfio-pci')"
