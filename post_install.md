Windows 11 ARM on Asahi Linux: High-Resolution Setup Guide
This guide details how to move from a fresh Windows 11 installation to a high-performance, high-resolution environment on Apple Silicon using QEMU.

# Assumptions
You installed Win11Arm with the official Microsoft ISO and using `win11_install.sh`
We will launch everything here with `win11_run.sh`

# Prepare UEFI Firmware (2x 64MB Flash Files)
QEMU’s virt machine type requires two specific flash drives for the BIOS: one for the EFI (Read-Only) and one for your saved EFI vars(Read-Write). These must be exactly 64MB.

## 1. Create from source and pad
```bash
dd if=/usr/share/edk2/aarch64/QEMU_EFI.fd of=QEMU_EFI.fd conv=notrunc
truncate -s 64M QEMU_EFI.fd  # Remains unchanged

# This file is what allows the BIOS to "remember" your resolution after setting
dd if=/usr/share/edk2/aarch64/QEMU_VARS.fd of=win11arm_vars.fd conv=notrunc
truncate -s 64M win11arm_vars.fd
```

# Phase 1: The "Bootstrap" Launch
Windows doesn't have VirtIO GPU drivers built-in. To see the screen and install them, we use a temporary "dumb" display called ramfb.

```bash
qemu-system-aarch64 \
    ... 
    # Include BOTH of these displays:
    -device virtio-gpu-pci
    -device ramfb 
    ...
    # Also include the virtio-win drivers iso
    -drive if=none,id=drivers,format=raw,media=cdrom,file=./virtio-win.iso
    -device usb-storage,drive=drivers
```

# Phase 2: Driver Installation
Run the bootstrap script. Windows will boot in a small, low-res window.

Log in to Windows.

First, some VirtIO drivers work through the installer as-is. 

Install them with the fat installer at D:\virtio-win-guest-tools.exe

For VirtIO GPU: Right-click Start > Device Manager.

Expand Other devices. You will see "Video Controller" with a yellow warning.

Right-click it → Update driver.

Select Browse my computer for drivers.

Select Let me pick from a list of available drivers on my computer.

Scroll down and select Display adapters (even if it wasn't in the main list before) and click Next.

Click Have Disk...

Browse to your VirtIO ISO: D:\viogpudo\w11\ARM64.

Select viogpudo.inf.

It should now show "Red Hat VirtIO GPU DOD Controller

Shut down the VM through Windows. It should gracefully shut down and auto-close the QEMU window.

# Phase 3: Setting Permanent High Resolution
Now that the driver is installed, we remove the "training wheels" (ramfb) and tell the BIOS to use a higher resolution.

Edit your script: Delete the line `-device ramfb`

Start the VM and immediately mash the ESC key to enter the grey BIOS menu.

Navigate to: Device Manager → OVMF Platform Configuration.

Change Preferred Resolution to your target (e.g., 12560x1600 for M1 MacBook Air).

Select "Commit and Save", ESC to back out, and select Reset to save settings and reboot (NOT 'Quit'!).

Use full-screen in KDE with `Ctrl+Alt+f`


# Phase 4: `virtio-fs` Shared Folder Setup on guest
This guide covers the Windows 11 guest configuration required to mount a virtio-fs shared directory. Because the community-compiled ARM64 VirtIO drivers lack strict Microsoft WHQL signatures, this process requires permanently enabling Test Mode to bypass the signature block and manually registering the background service.

1. Enable Test Mode

  Windows 11 will block the unsigned VirtIO-FS driver by default. You must enable Test Mode so the OS accepts the driver on every boot.

  Open the Start menu, type cmd, right-click Command Prompt, and select Run as administrator:
      `bcdedit /set testsigning on`

  Restart the virtual machine. You should now see a "Test Mode" watermark in the bottom right corner of your desktop.

2. Install WinFSP

  Windows requires a FUSE (Filesystem in Userspace) wrapper to understand the shared Linux file system.

  Download the latest WinFSP release from winfsp.dev/rel/.

  Run the .msi installer using the default "Core" settings.

3. Install the VirtIO-FS Kernel Driver

  Ensure your virtio-win ISO is mounted to the VM.

  Open File Explorer and navigate to the `\viofs\w11\ARM64` folder on the CD drive.

  Right-click the viofs.inf file (it has a small gear on its icon).

  Select Show more options at the bottom of the menu, then click Install.

  A red security warning box will appear. Click Install this driver software anyway.

4. Manually Register the Background Service

  The .inf file only installs the deep hardware driver. You must manually extract and register the companion application that actively maps the drive into File Explorer.

  Open your C: drive and create a new folder named VirtioFS (`C:\VirtioFS`).

  Go back to your mounted virtio-win CD drive (`\viofs\w11\ARM64`).

  Copy the virtiofs.exe application file and paste it into your new `C:\VirtioFS` folder.

  Open an Administrator Command Prompt and create the system service by running this exact command:
      `sc.exe create VirtioFsSvc binpath="C:\VirtioFS\virtiofs.exe" start=auto DisplayName="VirtIO-FS Service"`
      
  Start the service immediately:
      `sc.exe start VirtioFsSvc`

5. Verify the Connection

  Open File Explorer and navigate to This PC. You will see a new Network Drive (usually assigned to Z:) containing all the files shared from your host machine.