# EMMC SSD Setup Instructions

## Installing Ubuntu on eMMC
1. **Download Ubuntu**: Obtain the latest version of Ubuntu for your architecture.
2. **Create a Bootable USB Drive**: Use tools like Rufus or Balena Etcher to create a bootable USB drive with the downloaded Ubuntu ISO.
3. **Boot from USB**: Insert the USB drive into the ZimaBoard and power it on. Access the boot menu (usually by pressing F7, F12, or Esc) and select the USB drive.
4. **Install Ubuntu**: Follow the on-screen instructions to install Ubuntu. When prompted, select the eMMC storage as the installation target.

## Directing Write-Intensive Operations to an External SSD
1. **Connect External SSD**: Ensure your external SSD is connected to the ZimaBoard.
2. **Format the SSD**: Open a terminal and format the SSD to the desired filesystem (e.g., ext4).
   ```bash
   sudo mkfs.ext4 /dev/sdX
   ```
   Replace `/dev/sdX` with the actual device identifier for your SSD.
3. **Mount the SSD**: Create a mount point and mount the SSD.
   ```bash
   sudo mkdir /mnt/external_ssd
   sudo mount /dev/sdX /mnt/external_ssd
   ```
4. **Update fstab**: To ensure the SSD mounts automatically on boot, edit the `/etc/fstab` file.
   ```bash
   sudo nano /etc/fstab
   ```
   Add the following line:
   ```
   /dev/sdX /mnt/external_ssd ext4 defaults 0 2
   ```
5. **Redirect Write-Intensive Operations**: Depending on the applications you use, you can change the default paths to point to the SSD.
   For example, to redirect a database storage path:
   ```bash
   mv /var/lib/mysql /mnt/external_ssd/
   ln -s /mnt/external_ssd/mysql /var/lib/mysql
   ```

Ensure you adjust commands based on your specific needs and configurations. 

Happy computing!