# After reboot (vfio GPU passthrough)

Check that the NVIDIA GPU is bound to vfio-pci:

```bash
lspci -k -s 01:00.0
```

You should see **Kernel driver in use: vfio-pci**. Then add both PCI devices (01:00.0 and 01:00.1) to the VM in virt-manager.
