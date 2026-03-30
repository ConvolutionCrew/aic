#!/usr/bin/env bash
# Install the "bind GPU to vfio at every boot" service.
# Run once with: sudo bash scripts/install_vfio_claim_service.sh
# This runs vfio_claim_gpu.sh early at boot so the GPU is bound to vfio-pci before the display manager loads nvidia.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $(id -u) -eq 0 ]] || { echo "Run with sudo."; exit 1; }

echo "=== Installing /usr/local/bin/vfio_claim_gpu.sh ==="
cp "$SCRIPT_DIR/vfio_claim_gpu.sh" /usr/local/bin/
chmod +x /usr/local/bin/vfio_claim_gpu.sh

echo "=== Installing systemd service vfio-claim-gpu.service ==="
cp "$SCRIPT_DIR/vfio-claim-gpu.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable vfio-claim-gpu.service

echo ""
echo "Done. The service will run at every boot before the display manager."
echo "Reboot to test: sudo reboot"
echo "After reboot, check: lspci -k -s 01:00.0   (should show vfio-pci)"
echo ""
echo "To disable: sudo systemctl disable vfio-claim-gpu.service && sudo reboot"
echo "To remove:  sudo systemctl disable vfio-claim-gpu.service; sudo rm /etc/systemd/system/vfio-claim-gpu.service /usr/local/bin/vfio_claim_gpu.sh; sudo systemctl daemon-reload"