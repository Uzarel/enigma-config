# enigma-config
Setup guide for workstation Enigma based on Ubuntu Server 22.04

---

### **Table of Contents**

1. **Install Ubuntu Server**
2. **Install Desktop Environment (XFCE)**
3. **Enable Remote Access**
   - a. Configure SSH on Port 33
   - b. Install and Configure x2go Server
4. **User Management with Resource Limitations**
5. **Software and Applications**
   - a. Install NVIDIA Drivers with CUDA Support
   - b. Install Docker and NVIDIA Container Toolkit using `docker_install.sh`
   - c. Allow Non-Sudo Users to Install Programs Locally
   - d. Install Essential Applications Globally
6. **Security**
7. **System Behavior**
8. **Monitoring and Maintenance**

---

### **1. Install Ubuntu Server**

**a. Download Ubuntu Server:**

- Obtain the Ubuntu 22.04 LTS Server ISO from the [official website](https://ubuntu.com/download/server).

**b. Create a Bootable USB Drive:**

- Use tools like **Rufus** (Windows) or **Etcher** (Linux/Mac) to create a bootable USB drive with the downloaded ISO.

**c. Install Ubuntu Server:**

- Boot the workstation from the USB drive.
- Follow the on-screen instructions to install Ubuntu Server.
  - Set up the hostname, username, and password.
  - Partition the disk as needed.
  - Do not install any additional software during installation; we'll handle that later.

---

### **2. Install Desktop Environment (XFCE)**

**a. Update the System:**

```bash
sudo apt update && sudo apt upgrade -y
```

**b. Install XFCE and Related Packages:**

```bash
sudo apt install -y xfce4 xfce4-goodies
```

**c. Install LightDM and LightDM GTK Greeter:**

```bash
sudo apt install -y lightdm lightdm-gtk-greeter
```

- If prompted, select **lightdm** as the default display manager.

**d. Remove Unity Greeter Configuration:**

Remove the Unity greeter configuration file to avoid conflicts with XFCE:

```bash
sudo rm /usr/share/lightdm/lightdm.conf.d/50-unity-greeter.conf
```

**e. Create an XFCE Configuration File for LightDM:**

Create a new configuration file:

```bash
sudo nano /usr/share/lightdm/lightdm.conf.d/50-xfce-greeter.conf
```

**f. Populate the Configuration File:**

Add the following content:

```conf
[SeatDefaults]
greeter-session=lightdm-gtk-greeter
user-session=xfce
```

**g. Set Correct Permissions (if necessary):**

```bash
sudo chmod 644 /usr/share/lightdm/lightdm.conf.d/50-xfce-greeter.conf
```

**h. Restart LightDM or Reboot the System:**

```bash
sudo systemctl restart lightdm
```

- Alternatively, reboot the system:

  ```bash
  sudo reboot
  ```

**i. Verify the Desktop Environment:**

- Log in to ensure XFCE loads correctly.

---

### **3. Enable Remote Access**

#### **a. Configure SSH on Port 33**

**i. Install OpenSSH Server:**

```bash
sudo apt install -y openssh-server
```

**ii. Change SSH Port:**

Edit the SSH daemon configuration:

```bash
sudo nano /etc/ssh/sshd_config
```

- Find and modify:

  ```conf
  Port 33
  ```

**iii. Configure SSH to Listen on Specific Interfaces (Optional):**

```conf
ListenAddress 192.168.1.10
```

**iv. Restart SSH Service:**

```bash
sudo systemctl restart ssh
```

**v. Adjust Firewall Settings:**

```bash
sudo ufw allow 33/tcp
```

#### **b. Install and Configure x2go Server**

**i. Install x2go Server:**

```bash
sudo apt update
sudo apt install -y x2goserver x2goserver-xsession
```

**ii. Ensure XFCE is Installed:**

- Already installed in **Section 2**.

**iii. Verify SSH Configuration:**

- Ensure SSH is running on port 33 and allows key-based authentication.

**iv. Adjust Firewall Settings:**

- SSH port 33 is already allowed.

**v. Install x2go Client on a Remote Machine:**

- **Windows/macOS:** Download from [x2go downloads](https://wiki.x2go.org/doku.php/download:start#x2go_client).
- **Linux:** Install via package manager.

**vi. Configure a New Session in x2go Client:**

- Set **Host** to your server's IP.
- Set **Login** to your username.
- Set **SSH Port** to 33.
- Choose **XFCE** as the session type.
- Use SSH key authentication.

**vii. Connect to the Server Using x2go Client:**

- Initiate the connection and verify that XFCE loads.

---

### **4. User Management with Resource Limitations**

**We will use the `add_user.sh` script to add users with resource limitations.**

#### **a. Prepare the `add_user.sh` Script**

**i. Obtain the Script:**

Create the script file:

```bash
sudo nano /usr/local/bin/add_user.sh
```

**ii. Paste the Script Content:**

Copy the `add_user.sh` script content into the file.

**iii. Make the Script Executable:**

```bash
sudo chmod +x /usr/local/bin/add_user.sh
```

**NEEDS TO BE INVESTIGATED!**


**iv. Install Required Packages:**

Ensure necessary packages are installed:

```bash
sudo apt install -y quota quotatool
```

- **Note:** Disk quotas require the filesystem to support them.

#### **b. Enable Disk Quotas on the Root Filesystem**

**i. Modify `/etc/fstab`:**

Edit the file:

```bash
sudo nano /etc/fstab
```

- Add `usrquota,grpquota` to the root filesystem options:

  ```fstab
  UUID=... / ext4 defaults,usrquota,grpquota 0 1
  ```

**ii. Remount the Root Filesystem:**

```bash
sudo mount -o remount /
```

**iii. Initialize Quota Database:**

```bash
sudo quotacheck -cum /
```

**iv. Enable Quotas:**

```bash
sudo quotaon -v /
```

**FINISH INVESTIGATION**

#### **c. Add a New User with Resource Limitations**

**Usage of the Script:**

```bash
sudo /usr/local/bin/add_user.sh [OPTIONS] USERNAME PUBKEY
```

**Options:**

- `--cpu-quota=CPU_QUOTA_%` (default: 12800%)
- `--memory-quota=MEMORY_QUOTA_GB` (default: 64 GB)
- `--disk-quota=DISK_QUOTA_GB` (default: 100 GB)
- `--sudo` (to add the user to the sudo group)
- `--docker` (to add the user to the docker group)

**Example:**

1. **Create a New User with Defaults:**

   ```bash
   sudo /usr/local/bin/add_user.sh username /path/to/public_key.pub
   ```

2. **Create a User with Specific Quotas and Docker Access:**

   ```bash
   sudo /usr/local/bin/add_user.sh --cpu-quota=200% --memory-quota=16 --disk-quota=50 --docker username /path/to/public_key.pub
   ```

**Explanation:**

- **CPU Quota:** Limits CPU usage via systemd slices.
- **Memory Quota:** Limits RAM usage via systemd slices.
- **Disk Quota:** Limits disk space using filesystem quotas.
- **Docker Group:** Allows the user to run Docker commands without `sudo`.

**NEEDS TO BE INVESTIGATED!**
**d. Implement GPU Limitations (Optional)**

To limit GPU access per user:

**i. Modify the `add_user.sh` Script:**

After the resource quotas section, add:

```bash
# Set CUDA_VISIBLE_DEVICES for the user
mkdir -p "/etc/systemd/system/user@${NEW_UID}.service.d"
cat <<EOF > "/etc/systemd/system/user@${NEW_UID}.service.d/gpu.conf"
[Service]
Environment=CUDA_VISIBLE_DEVICES=0
EOF

# Reload systemd daemon
systemctl daemon-reload
```

- This limits the user to GPU 0.

---

**FINISH INVESTIAGATION**

### **5. Software and Applications**

#### **a. Install NVIDIA Drivers with CUDA Support**

**i. Identify Your NVIDIA GPU Model:**

```bash
lspci | grep -i nvidia
```

**ii. Determine the Recommended Driver Version:**

```bash
sudo apt install -y ubuntu-drivers-common
ubuntu-drivers devices
```

- Look for the driver marked as **`recommended`**.

**iii. Install the Recommended NVIDIA Driver:**

Replace `xxx` with the driver version (e.g., `nvidia-driver-535`):

```bash
sudo apt install -y nvidia-driver-xxx
sudo update-initramfs -u
sudo apt install --reinstall linux-headers-$(uname -r)
```

**NEEDS TO BE INVESTIGATED!**

**iv. Install NVIDIA CUDA Toolkit (if needed):**

```bash
sudo apt install -y nvidia-cuda-toolkit
```

**FINISH INVESTIGATION**

**v. Reboot the System:**

```bash
sudo reboot
```

**vi. Verify the Driver Installation:**

```bash
nvidia-smi
```

#### **b. Install Docker and NVIDIA Container Toolkit using `docker_install.sh`**

**i. Prepare the `docker_install.sh` Script**

**1. Create the Script File:**

```bash
sudo nano /usr/local/bin/docker_install.sh
```

**2. Paste the Script Content:**

Copy the content of the `docker_install.sh` script into the file.

**3. Make the Script Executable:**

```bash
sudo chmod +x /usr/local/bin/docker_install.sh
```

**ii. Run the Script to Install Docker and Components**

```bash
sudo /usr/local/bin/docker_install.sh
```

**iii. Follow the Prompts:**

- The script is interactive. It will ask:

  - Whether to install Docker Compose V2.
  - Whether to install QEMU for cross-platform builds.
  - Whether to install the NVIDIA Container Runtime.

- **Recommendations:**

  - **Install Docker Compose V2:** Yes
  - **Install QEMU:** Based on your needs.
  - **Install NVIDIA Runtime:** Yes (if you have compatible NVIDIA drivers)

**iv. Add Users to the Docker Group:**

- The script adds the current user to the `docker` group.
- For other users, ensure they are added to the `docker` group during user creation (use the `--docker` option with `add_user.sh`).

**v. Log Out and Log Back In:**

- To apply group membership changes.

**vi. Verify Docker Installation:**

```bash
docker --version
```

**vii. Verify Docker Compose Installation:**

```bash
docker compose version
```

**viii. Test Docker with NVIDIA Runtime:**

```bash
docker run --rm --gpus all nvidia/cuda:12.1.1-runtime-ubuntu22.04 nvidia-smi
```

- Should display GPU information.

#### **c. Allow Non-Sudo Users to Install Programs Locally**

- Users can install programs in their home directories.
- Encourage the use of:

  - **Python:** `virtualenv`
  - **Node.js:** `nvm`
  - **Ruby:** `rbenv`
  - **Go:** Use local `$GOPATH`

#### **d. Install Essential Applications Globally**

```bash
sudo apt install -y firefox neofetch htop
```

- **Explanation:**
  - **Firefox:** Web browser.
  - **Neofetch:** System information tool.
  - **Htop:** Interactive process viewer.

---

**NEED TO ADD MANY MORE APPS**

### **6. Security**

#### **a. Set Up UFW Firewall**

**i. Install UFW:**

```bash
sudo apt install -y ufw
```

**ii. Configure Default Policies:**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**iii. Allow SSH on Port 33:**

```bash
sudo ufw allow 33/tcp
```

**iv. Enable UFW:**

```bash
sudo ufw enable
```

#### **b. Implement SSH Key Authentication**

- Already configured during user creation with `add_user.sh`.

#### **c. Install and Configure Fail2Ban**

**i. Install Fail2Ban:**

```bash
sudo apt install -y fail2ban
```

**ii. Create Local Jail Configuration:**

```bash
sudo nano /etc/fail2ban/jail.local
```

**iii. Add SSH Jail Configuration:**

```conf
[sshd]
enabled = true
port = 33
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 360
```

**iv. Restart Fail2Ban:**

```bash
sudo systemctl restart fail2ban
```

#### **d. Secure Docker Daemon**

- Ensure Docker socket is not exposed over the network.
- Do not run containers with `--privileged` unless necessary.
- Regularly update Docker and review security settings.

---

### **7. System Behavior**

#### **a. Enable Automatic Power-On After Power Loss**

**i. Access BIOS/UEFI Settings:**

- Reboot and press the key to enter BIOS/UEFI (e.g., **F2**, **Delete**, or **Esc**).

**ii. Navigate to Power Management Settings:**

- Look for options like **"AC Power Recovery"** or **"After Power Loss"**.

**iii. Set to "Power On":**

- Change the setting to **"Power On"** or **"Last State"**.

**iv. Save and Exit BIOS/UEFI:**

- Save changes and reboot.

---

### **8. Monitoring and Maintenance**

#### **a. Set Up User Activity Reporting**

**i. Install Process Accounting Tools:**

```bash
sudo apt install -y acct
```

**ii. Enable Process Accounting:**

```bash
sudo accton on
```

**iii. Generate Reports:**

- **Logged-in Users:**

  ```bash
  who
  ```

- **CPU Usage per User:**

  ```bash
  sudo sa -u
  ```

- **Memory Usage:**

  ```bash
  ps aux --sort=-%mem | head -n 10
  ```

- **GPU Usage:**

  ```bash
  nvidia-smi
  ```

#### **b. Install System Monitoring Tools**

- Use `htop`:

  ```bash
  htop
  ```

#### **c. Enable Unattended Upgrades**

**i. Install Unattended Upgrades:**

```bash
sudo apt install -y unattended-upgrades
```

**ii. Configure Unattended Upgrades:**

- Ensure it's enabled:

  ```bash
  sudo dpkg-reconfigure --priority=low unattended-upgrades
  ```

---

**Final Notes:**

- **User Education:**

  - Provide users with information on:

    - How to generate credentials (generate SSH key and send to administrator).
    - How to configure and use x2go client.
    - Guidelines for resource usage (remember to logout after using the workstation).
    - How to use Docker and Docker Compose (optional).

- **Regular Maintenance:**

  - Keep the system and applications updated.
  - Monitor system logs for unusual activity.

---

**By following these updated steps, you will set up a workstation with Docker and NVIDIA support, user accounts with resource limitations, and secure remote access using x2go. The `docker_install.sh` and `add_user.sh` scripts streamline the installation and user management processes.**

---

### **Appendix: Scripts**

**1. `docker_install.sh`**

- Located at `/usr/local/bin/docker_install.sh`
- Ensure it's executable: `sudo chmod +x /usr/local/bin/docker_install.sh`
- Run with: `sudo /usr/local/bin/docker_install.sh`

**2. `add_user.sh`**

- Located at `/usr/local/bin/add_user.sh`
- Ensure it's executable: `sudo chmod +x /usr/local/bin/add_user.sh`
- Usage:

  ```bash
  sudo /usr/local/bin/add_user.sh [OPTIONS] USERNAME PUBKEY
  ```

---

### **Additional Resources for Users**

- **Docker Documentation:**

  - [Get Started with Docker](https://docs.docker.com/get-started/)
  - [Docker Compose Documentation](https://docs.docker.com/compose/)

- **NVIDIA Container Toolkit Documentation:**

  - [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

- **x2go Documentation:**

  - [x2go Official Documentation](https://wiki.x2go.org/doku.php)

- **Remote Development using SSH:**

  - [Visual Studio Code Remote-SSH](https://code.visualstudio.com/docs/remote/ssh)
