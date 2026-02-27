# Instructions:

Derived from the [Asahi Linux Docs](https://asahilinux.org/docs/sw/windows-11-vm/), original README [here](windows-11-vm.md).

Start with [win11_install.sh](win11_install.sh).

Then look at the [post install instructions](post-install.md) for setting up your host and guest to play nicely.

# Known working:
### System: Fedora Asahi Remix 42, on M1 MacBook Air 8GB (2020)
- Windows 11 ARM on QEMU as guest
- Office 365 Suite from official installer inside guest
- VirtIO GPU (i.e. Hardware accelerated graphics)
- VirtIO FS (Sharing a dir between host and guest)

Can also confirm Widevine DRM works on Fedora Asahi, via Thorium browser.

## Untested:
- Clipboard Sharing
- Audio