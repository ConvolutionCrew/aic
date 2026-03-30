# NVIDIA driver build failed: GPL symbol `rcu_read_unlock_strict`

Kernel **5.15.0-139** exports this symbol as GPL-only; the proprietary **510** driver cannot use it, so the DKMS build fails.

You have two ways to get the GPU working:

---

## Option A: Boot the older kernel (fastest)

Your NVIDIA 510 driver is **already built** for **5.15.0-87-generic**. Use that kernel:

1. Reboot the machine.
2. At the GRUB menu, choose **Advanced options for Ubuntu**.
3. Select **Ubuntu, with Linux 5.15.0-87-generic** (not 5.15.0-139).
4. Boot and log in.
5. Run:
   ```bash
   sudo modprobe nvidia
   nvidia-smi
   docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
   ```

To make 5.15.0-87 the default kernel so you don’t have to select it every time:

```bash
# Set default to 5.15.0-87-generic (run once)
sudo grub-set-default "1>2"   # adjust if your menu position differs; list with: grep menuentry /boot/grub/grub.cfg
# Or use: sudo sed -i 's/GRUB_DEFAULT=.*/GRUB_DEFAULT="Advanced options for Ubuntu>Ubuntu, with Linux 5.15.0-87-generic"/' /etc/default/grub && sudo update-grub
```

---

## Option B: Upgrade to the open-source kernel driver (stay on 5.15.0-139)

Use the **open** NVIDIA kernel modules (GPL-compatible), which work with newer kernels:

```bash
# Install the open driver (535)
sudo apt-get update
sudo apt-get install -y nvidia-driver-535-open

# Reboot
sudo reboot
```

After reboot, the driver should load on 5.15.0-139. Then:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
```

**Note:** The open driver may not support some features (e.g. vGPU, G-SYNC, Quadro Sync). For normal CUDA/Docker GPU use it is usually fine.

---

## Summary

| Option | Effort | Keeps kernel 5.15.0-139 | Notes |
|--------|--------|--------------------------|--------|
| **A** – Boot 5.15.0-87 | Reboot + pick kernel | No | Driver already built, no reinstall |
| **B** – Install 535-open | Install + reboot | Yes | New driver branch, open kernel modules |

Recommendation: try **Option A** first (boot 5.15.0-87). If you prefer to stay on 5.15.0-139, use **Option B**.
