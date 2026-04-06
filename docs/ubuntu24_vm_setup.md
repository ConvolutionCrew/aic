# Running AIC in an Ubuntu 24.04 VM

If your host is Ubuntu 20.04 (or older), the AIC toolkit needs **GLIBC 2.32+** (e.g. Ubuntu 24.04). Using a VM avoids upgrading the whole machine.

Choose one option below. Then install Ubuntu 24.04 Server or Desktop in the VM and follow the main [Getting Started](./getting_started.md) guide inside the VM.

---

## Option A: VirtualBox (simple GUI)

**1. Install VirtualBox**

```bash
sudo apt update
sudo apt install -y virtualbox
```

**2. Install Extension Pack (optional, for USB 2/3, RDP, etc.)**

- Download from [VirtualBox downloads](https://www.virtualbox.org/wiki/Downloads) → “Extension Pack”.
- In VirtualBox: **File → Preferences → Extensions → Add** and select the downloaded `.vbox-extpack`.

**3. Download Ubuntu 24.04 ISO**

- [Ubuntu 24.04 LTS Desktop](https://ubuntu.com/download/desktop) (GUI) or [Server](https://ubuntu.com/download/server) (no GUI).
- Save the `.iso` file.

**4. Create the VM**

- Open **VirtualBox** → **New**.
- **Name:** e.g. `Ubuntu 24.04 AIC`
- **Type:** Linux
- **Version:** Ubuntu (64-bit)
- **Memory:** 8192 MB or more (AIC recommends 32GB+; use as much as you can)
- **Create a virtual hard disk** → **VDI** → **Dynamically allocated** → e.g. **64 GB**
- **Settings → System → Processor:** 4+ cores if possible
- **Settings → Storage:** under “Controller: IDE”, click the disc icon → **Choose a disk file** → select the Ubuntu 24.04 ISO
- **Start** the VM and complete the Ubuntu installation. When done, you can detach the ISO in **Storage** so the VM boots from the disk.

**5. Inside the VM**

- Install VirtualBox Guest Additions (optional): **Devices → Insert Guest Additions CD image**, then run the installer on the VM.
- Follow [Getting Started](./getting_started.md): Docker, Distrobox, Pixi, clone the AIC repo, `pixi install`, then run the evaluation container and example policy.

---

## Option B: QEMU/KVM + virt-manager (native Linux)

**1. Install packages**

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
sudo usermod -aG kvm,libvirt $USER
```

Log out and back in (or reboot) so the group membership applies.

**2. Download Ubuntu 24.04 ISO**

- [Ubuntu 24.04 LTS Desktop](https://ubuntu.com/download/desktop) or [Server](https://ubuntu.com/download/server).

**3. Create the VM**

- Run **Virtual Machine Manager** (`virt-manager`).
- **File → New Virtual Machine**.
- **Local install media** → **Browse** and select the Ubuntu 24.04 ISO.
- Set **Memory** and **CPUs** (e.g. 8192 MB, 4 CPUs; more if you have RAM to spare).
- Create a disk (e.g. 64 GB).
- Finish and start the VM; complete the Ubuntu installation.

**4. Inside the VM**

- Follow [Getting Started](./getting_started.md) as on a normal Ubuntu 24.04 system.

---

## "No bootable device" in virt-manager

If the VM shows **No bootable device** when you start it, the virtual CD with the Ubuntu ISO is not attached or not first in the boot order. Do this:

**1. Power off the VM**

- In Virtual Machine Manager, select the VM.
- Click **Shut Down** (square icon) or **Virtual Machine → Shut Down**. Wait until it is fully off (not "Running").

**2. Open the VM’s hardware / details**

- Select the VM (one click).
- Click the **lightbulb** icon ( **Show virtual hardware details** ) in the toolbar, **or** use the menu **View → Details**.

**3. Attach the Ubuntu ISO to the CD drive**

- In the left list, click **SATA CDROM 1** or **IDE CDROM 1** (or the only CDROM entry).
- On the right, check **Connect**.
- Under **Source path**, choose **Browse** (or **Choose disk**).
- Select your **Ubuntu 24.04** ISO (e.g. `ubuntu-24.04.x-desktop-amd64.iso` from Downloads).
- Click **Apply** (bottom left) if the button is there.

**4. Set boot order**

- In the left list, open **Boot Options**.
- Check **Enable boot menu** (optional).
- In **Boot device order**, move **SATA CDROM 1** (or **IDE CDROM 1**) to **the top** (first).
- Click **Apply**.

**5. Start the VM**

- Click **Run** (play icon). It should boot from the ISO and show the Ubuntu installer. Choose **Try or Install Ubuntu** or **Install Ubuntu**.

After you finish installing Ubuntu, you can open **Boot Options** again and put the **disk** first and CDROM second (or disconnect the ISO) so the VM boots from the hard disk next time.

---

## Sharing files between host and VM (virt-manager)

You can share a host folder with the VM so you can edit code on the host and run it in the VM (or the other way around).

### Method 1: Virtio 9p (folder passthrough) — recommended

**On the host (VM must be shut down):**

1. Open **Virtual Machine Manager** → select the VM → **Show virtual hardware details** (lightbulb).
2. Click **Add Hardware** (bottom left).
3. Choose **Filesystem**.
4. Set **Driver** to **virtio-9p** (or the default).
5. **Source path:** host folder to share, e.g. `/home/rkrishnan/Projects` (parent of your `aic` clone).
6. **Target path:** a tag name the guest will use, e.g. `hostshare` (no path, just a name).
7. Click **Finish**, then start the VM.

**Inside the VM (Ubuntu 24.04):**

```bash
# Create mount point
sudo mkdir -p /mnt/hostshare

# Mount (use the tag you set as Target path)
sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt/hostshare

# Use it (e.g. copy the aic repo into the VM, or work directly)
ls /mnt/hostshare
```

To mount automatically at boot, add to `/etc/fstab` inside the VM:

```bash
echo 'hostshare /mnt/hostshare 9p trans=virtio,version=9p2000.L 0 0' | sudo tee -a /etc/fstab
sudo mount -a
```

**Note:** If the VM user needs to write to the share, ensure the host folder has permissions the VM can use (e.g. `chmod -R o+rX /home/rkrishnan/Projects` on the host, or match UIDs).

---

### Method 2: Samba (network share)

**On the host:**

```bash
sudo apt install -y samba
sudo mkdir -p /home/rkrishnan/shared
chmod 755 /home/rkrishnan/shared
```

Edit `/etc/samba/smb.conf` and add at the end (use your host username):

```ini
[shared]
path = /home/rkrishnan/shared
read only = no
guest ok = no
valid users = rkrishnan
```

Then: `sudo smbpasswd -a rkrishnan` (set a Samba password), `sudo systemctl restart smbd`.

**In the VM:** Install the VM’s IP (e.g. **Settings → Network** in the VM, or `ip addr`). Then in the VM:

```bash
sudo apt install -y cifs-utils
mkdir -p ~/hostshare
# Replace 192.168.x.x with the host IP (from host: ip -4 addr show | grep inet)
sudo mount -t cifs -o username=rkrishnan,uid=$UID //192.168.x.x/shared ~/hostshare
```

You can find the host IP from the host with `ip route get 8.8.8.8` or by checking the default gateway from inside the VM and using the same subnet.

---

### Method 3: Copy files with SCP

**In the VM:** enable SSH and note the VM’s IP:

```bash
sudo apt install -y openssh-server
ip -4 addr show
```

**From the host:** copy files into the VM (replace `vmuser@192.168.x.x` with the VM user and IP):

```bash
scp -r /home/rkrishnan/Projects/aic vmuser@192.168.x.x:~/
```

**From the VM:** copy files to the host:

```bash
scp -r ~/somefile rkrishnan@192.168.x.x:~/Downloads/
```

---

## Resource tips for AIC inside the VM

- **RAM:** 8 GB minimum; 16 GB+ recommended for Gazebo + RViz.
- **CPU:** 4+ cores.
- **Disk:** 64 GB+ for OS + Docker images + AIC workspace.
- **GPU passthrough** (optional): If you want the VM to use the host GPU for Gazebo, you need PCI passthrough (e.g. VFIO). Otherwise Gazebo will use software rendering and may be slower.
