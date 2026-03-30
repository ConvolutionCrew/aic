#!/bin/bash
# Bind NVIDIA GPU (01:00.0 and 01:00.1) to vfio-pci so the VM can use it.
# Run at boot by systemd (vfio-claim-gpu.service) before the display manager loads.

set -e
VGPU="0000:01:00.0"
VAUDIO="0000:01:00.1"
SYS_PCI="/sys/bus/pci/devices"

modprobe vfio-pci 2>/dev/null || true
modprobe vfio_iommu_type1 2>/dev/null || true

# If nvidia already has the device, unbind it first
for dev in "$VGPU" "$VAUDIO"; do
  driver="$SYS_PCI/$dev/driver"
  if [[ -L "$driver" ]]; then
    drv_name=$(basename "$(readlink "$driver")")
    if [[ "$drv_name" == nvidia* ]] || [[ "$drv_name" == nouveau ]]; then
      echo "$dev" > "$SYS_PCI/$dev/driver/unbind" 2>/dev/null || true
    fi
  fi
done

# Claim GPU and audio with vfio-pci (vendor device format for new_id: "vendor device")
echo "10de 24b6" > /sys/bus/pci/drivers/vfio_pci/new_id 2>/dev/null || true
echo "10de 228b" > /sys/bus/pci/drivers/vfio_pci/new_id 2>/dev/null || true
