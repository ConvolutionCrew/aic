#!/bin/bash
set -e
echo "=== 1. Installing kernel headers for $(uname -r) ==="
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r)

echo ""
echo "=== 2. Building and installing NVIDIA driver for current kernel ==="
sudo dkms install nvidia/510.39.01 -k 5.15.0-139-generic

echo ""
echo "=== 3. Loading NVIDIA kernel module ==="
sudo modprobe nvidia

echo ""
echo "=== 4. Checking nvidia-smi on host ==="
nvidia-smi

echo ""
echo "=== 5. Enabling nvidia module to load on boot ==="
echo "nvidia" | sudo tee /etc/modules-load.d/nvidia.conf

echo ""
echo "=== 6. Testing Docker GPU access ==="
docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi

echo ""
echo "Done. NVIDIA driver is loaded and Docker can use the GPU."
