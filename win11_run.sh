#!/bin/bash
set -e

# 1. Assert the current working directory
if [[ "$PWD" != "$HOME/windows11" ]]; then
  echo "Error: This script must be run from ~/windows11" >&2
  echo "Current directory is: $PWD" >&2
  exit 1
fi

SHARE_DIR="./share"
SOCK_PATH="/tmp/vfs.sock"
PID_PATH="/tmp/vfs.sock.pid"

# 1. Ensure the shared directory exists
mkdir -p "$SHARE_DIR"

# 2. Clean up any stale socket files from a previous crash
sudo rm -f "$SOCK_PATH" "$PID_PATH"

echo "Starting virtiofsd background service..."
# Start the share dir daemon in the background using '&', creating a socket file at /tmp/vfs.sock
sudo /usr/libexec/virtiofsd --socket-path="$SOCK_PATH" --shared-dir="$SHARE_DIR" &
VFS_PID=$!  # Must be set directly after to capture background process PID

# 4. Give the daemon a second to create the socket file before QEMU looks for it
sleep 1
# Grant your regular user ownership of the socket
sudo chown $USER "$SOCK_PATH"  # Must be done after socket created

# 5. Set a trap to kill the daemon when QEMU closes (or if you hit Ctrl+C)
trap 'echo "Shutting down virtiofsd...";
sudo kill $VFS_PID 2>/dev/null; 
sudo rm -f "$SOCK_PATH" "$PID_PATH"' EXIT

# 6. Launch QEMU (this command blocks the script until the VM shuts down)
echo "Starting Windows 11 VM..."
performance_cores=$(awk '
  /^processor/ { proc=$3 } 
  /^CPU part/ {
    if ($4 == "0x023" || $4 == "0x025" || $4 == "0x029" || $4 == "0x033" || $4 == "0x035" || $4 == "0x039")
      procs=procs ? procs","proc : proc
  } END { print procs }
' /proc/cpuinfo)

# Using:
cores=4  # Max 4 performance cores on M1 MacBook Air
memory=4G  # Max 8GB total on M1 MacBook Air

taskset -c "$performance_cores" \
  qemu-system-aarch64 \
    -device virtio-gpu-pci \
    -display sdl,gl=on \
    -cpu host \
    -M virt \
    -enable-kvm \
    -m $memory \
    -smp $cores \
    -drive if=pflash,format=raw,readonly=on,file=./QEMU_EFI.fd \
    -drive if=pflash,format=raw,file=./win11arm_vars.fd \
    -hda win11.qcow2 \
    -device qemu-xhci \
    -object rng-random,filename=/dev/urandom,id=rng0 \
    -device virtio-rng-pci,rng=rng0 \
    -audio driver=pipewire,model=virtio \
    -device usb-kbd \
    -device usb-tablet \
    -rtc base=localtime \
    -nic user,model=virtio-net-pci \
    -object memory-backend-memfd,id=mem,size=$memory,share=on \
    -machine virt,memory-backend=mem \
    -chardev socket,id=char0,path=/tmp/vfs.sock \
    -device vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=share 

# Access shared folder in guest at: Z:\
# Full screen the guest with: Ctrl+Alt+f (on KDE Plasma)
# Drive mounts:
# "virtio-win.iso": https://github.com/virtio-win/kvm-guest-drivers-windows/wiki/Driver-installation
#     -device usb-storage,drive=virtio-drivers \
#     -drive if=none,id=virtio-drivers,format=raw,media=cdrom,file=./virtio-win.iso
# "installer.iso": https://www.microsoft.com/en-us/software-download/windows11arm64
#     -device usb-storage,drive=install \
#     -drive if=none,id=install,format=raw,media=cdrom,file=installer.iso \
# Displays:
#     -device virtio-gpu-pci \
#     -device ramfb \
# Stock EFI:
#     -bios /usr/share/edk2/aarch64/QEMU_EFI.fd \