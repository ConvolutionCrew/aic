# Binding NVIDIA GPU to vfio-pci for VM Passthrough

This binds your host's NVIDIA GPU to the **vfio-pci** driver so you can pass it through to a KVM VM. **After this, the host will not use the NVIDIA GPU** (your laptop display will use Intel integrated graphics, or you must have another display path).

**Your GPU IDs:** `10de:24b6` (graphics) and `10de:228b` (HDMI/DP audio). Both must be bound.

---

## Step 1: Create vfio-pci config

```bash
sudo tee /etc/modprobe.d/vfio.conf << 'EOF'
# Bind NVIDIA GPU (01:00.0) and its audio (01:00.1) to vfio-pci
options vfio-pci ids=10de:24b6,10de:228b
EOF
```

---

## Step 2: Blacklist nvidia and nouveau

So they never load and vfio-pci can claim the GPU:

```bash
sudo tee /etc/modprobe.d/blacklist-nvidia-passthrough.conf << 'EOF'
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist nouveau
EOF
```

---

## Step 3: Add vfio to initramfs (so it’s active at boot)

```bash
echo "vfio_pci"    | sudo tee -a /etc/initramfs-tools/modules
echo "vfio"        | sudo tee -a /etc/initramfs-tools/modules
echo "vfio_iommu_type1" | sudo tee -a /etc/initramfs-tools/modules
sudo update-initramfs -u
```

---

## Step 4: Reboot

```bash
sudo reboot
```

---

## After reboot — check that vfio has the GPU

Run:

```bash
lspci -k -s 01:00.0
```

Under **Kernel driver in use:** you should see **vfio-pci**, not **nvidia**. If you do, passthrough is active; add both PCI devices to the VM (Step 5).

---

## Step 5: Use the GPU in the VM

In virt-manager, add both PCI Host Devices to the VM:

- **0000:01:00.0** – NVIDIA Corporation (VGA)
- **0000:01:00.1** – NVIDIA Corporation (Audio)

Start the VM and install the NVIDIA driver inside the guest (Ubuntu 24.04).

---

## Run vfio-claim at every boot (alternative to blacklist)

If the GPU still shows **nvidia** after blacklist + initramfs, use a **systemd service** that runs **before** the display manager and binds the GPU to vfio-pci at each boot:

1. Install the service (run once):

   ```bash
   cd /path/to/aic
   sudo bash scripts/install_vfio_claim_service.sh
   ```

2. Reboot. The service runs early and binds the GPU to vfio-pci before GDM/nvidia load.

3. Check: `lspci -k -s 01:00.0` should show **vfio-pci**.

To disable: `sudo systemctl disable vfio-claim-gpu.service` then reboot. To remove completely: `sudo systemctl disable vfio-claim-gpu.service; sudo rm /etc/systemd/system/vfio-claim-gpu.service /usr/local/bin/vfio_claim_gpu.sh; sudo systemctl daemon-reload`.

---

## Reverting (use the GPU on the host again)

1. Remove the configs:

   ```bash
   sudo rm -f /etc/modprobe.d/vfio.conf /etc/modprobe.d/nvidia-vfio.conf /etc/modprobe.d/blacklist-nvidia-passthrough.conf
   ```

2. Remove the kernel blacklist from GRUB (edit `/etc/default/grub` and delete the ` modprobe.blacklist=nvidia,nvidiafb,nvidia_drm,nouveau` part from `GRUB_CMDLINE_LINUX_DEFAULT`), then:

   ```bash
   sudo update-grub
   ```

3. Re-enable the nvidia initramfs hook (if you disabled it):

   ```bash
   sudo mv /usr/share/initramfs-tools/hooks/framebuffer-nvidia.disabled /usr/share/initramfs-tools/hooks/framebuffer-nvidia
   ```

4. Remove vfio from initramfs modules:

   ```bash
   sudo sed -i '/vfio_pci/d' /etc/initramfs-tools/modules
   sudo sed -i '/^vfio$/d' /etc/initramfs-tools/modules
   sudo sed -i '/vfio_iommu_type1/d' /etc/initramfs-tools/modules
   sudo update-initramfs -u
   ```

5. Reboot.

---

## If the display doesn’t work after reboot

If the host screen stays black or doesn’t use Intel graphics:

- Reboot and hold **Shift** to get the GRUB menu → **Advanced options** → **Recovery mode** → **root shell**, then run the revert commands above and reboot again.
- Or from another machine over **SSH**, run the revert commands and reboot.
