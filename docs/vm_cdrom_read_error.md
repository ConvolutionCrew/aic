# Fix "Could not read from CDROM" in virt-manager

The VM runs as user **libvirt-qemu**, which often cannot read files from your home directory (e.g. `~/Downloads`). Copy the ISO to a path libvirt can read.

---

## Fix: copy ISO to libvirt images and use that path

**1. Copy the Ubuntu ISO** (run on the host):

```bash
sudo cp /home/rkrishnan/Downloads/ubuntu-24.04.4-desktop-amd64.iso /var/lib/libvirt/images/
sudo chmod 644 /var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso
```

**2. Point the VM’s CD to this path**

- In **Virtual Machine Manager**, shut down the VM.
- Open **Show virtual hardware details** (lightbulb).
- Select **SATA CDROM 1** (or **IDE CDROM 1**).
- Under **Source path**, click **Browse**.
  - If you don’t see `/var/lib/libvirt/images/`, choose **Browse Local** and go to:  
    **/var/lib/libvirt/images/**  
  - Or clear the path and type manually:  
    **/var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso**
- Ensure **Connect** is checked.
- Click **Apply**.

**3. Boot order**

- Open **Boot Options** and put the CDROM **first** in boot order. Apply.

**4. Start the VM**

- It should boot from the ISO without “could not read from CDROM”.

---

## If “Browse” doesn’t show /var/lib/libvirt/images

- In the CDROM **Source path** field, delete the current path and type exactly:

  ```
  /var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso
  ```

- Then enable **Connect** and **Apply**.
