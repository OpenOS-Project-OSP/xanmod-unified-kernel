#!/usr/bin/env bash
# packaging/alpine/install.sh — Alpine Linux kernel install
#
# Alpine uses musl libc and OpenRC. The kernel install convention differs
# from glibc distros:
#   - Kernel image → /boot/vmlinuz-xanmod
#   - System.map   → /boot/System.map-xanmod
#   - Modules      → /lib/modules/<version>/
#   - initramfs    → mkinitfs (Alpine's own tool, not mkinitcpio/dracut)
#   - Bootloader   → extlinux (syslinux) or grub, updated via update-extlinux
#
# Alpine does not use make install's default install path logic — we copy
# the image manually to match Alpine naming conventions.
#
# Environment:
#   KERNEL_SRC   path to compiled kernel source tree
#   KARCH        kernel architecture (x86 → x86_64 for Alpine)

set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?KERNEL_SRC not set}"
KARCH="${KARCH:?KARCH not set}"
ENABLE_BDFS="${ENABLE_BDFS:-0}"
BDFS_SRC="${BDFS_SRC:-}"

# shellcheck source=../lib/install-bdfs.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/packaging/lib/install-bdfs.sh"

cd "${KERNEL_SRC}"
KERNEL_VERSION="$(make -s kernelrelease)"
echo "==> Installing kernel ${KERNEL_VERSION} (Alpine Linux)"

# ── Verify musl toolchain ──────────────────────────────────────────────────────
if ldd --version 2>&1 | grep -q musl; then
  echo "  musl libc confirmed"
else
  echo "WARNING: musl libc not detected. Alpine kernels should be built with musl."
  echo "         Proceeding, but the resulting kernel may not boot correctly."
fi

# ── Install modules ────────────────────────────────────────────────────────────
echo "  Installing modules to /lib/modules/${KERNEL_VERSION}..."
make -j"$(nproc)" ARCH="${KARCH}" modules_install

# ── Copy kernel image ──────────────────────────────────────────────────────────
# Alpine naming convention: vmlinuz-xanmod (not vmlinuz-<version>)
# Keep a versioned copy alongside for multi-kernel setups.
echo "  Copying kernel image..."
case "${KARCH}" in
  x86|x86_64)
    KERNEL_IMAGE="arch/x86/boot/bzImage" ;;
  arm64)
    KERNEL_IMAGE="arch/arm64/boot/Image.gz" ;;
  riscv)
    KERNEL_IMAGE="arch/riscv/boot/Image.gz" ;;
  *)
    KERNEL_IMAGE="vmlinux" ;;
esac

install -Dm644 "${KERNEL_IMAGE}"    /boot/vmlinuz-xanmod
install -Dm644 "${KERNEL_IMAGE}"    "/boot/vmlinuz-${KERNEL_VERSION}"
install -Dm644 System.map           /boot/System.map-xanmod
install -Dm644 System.map           "/boot/System.map-${KERNEL_VERSION}"
install -Dm644 .config              "/boot/config-${KERNEL_VERSION}"

# ── Generate initramfs via mkinitfs ───────────────────────────────────────────
echo "  Generating initramfs via mkinitfs..."
if command -v mkinitfs &>/dev/null; then
  # mkinitfs reads /etc/mkinitfs/mkinitfs.conf for features
  mkinitfs -b / -f "$(cat /etc/mkinitfs/mkinitfs.conf \
    | grep '^features=' | cut -d'"' -f2 2>/dev/null \
    || echo 'ata base ide scsi usb virtio ext4')" \
    "${KERNEL_VERSION}"
else
  echo "ERROR: mkinitfs not found. Install mkinitfs: apk add mkinitfs" >&2
  exit 1
fi

# ── Update bootloader ──────────────────────────────────────────────────────────
echo "  Updating bootloader..."
if command -v update-extlinux &>/dev/null; then
  # extlinux/syslinux (most common on Alpine)
  update-extlinux 2>/dev/null || true
  echo "  extlinux updated. Verify /boot/extlinux.conf references vmlinuz-xanmod."
elif command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
else
  echo "WARNING: No bootloader tool found (update-extlinux / grub-mkconfig)."
  echo "         Update your bootloader manually to boot vmlinuz-xanmod."
fi

# ── Print extlinux stanza hint ─────────────────────────────────────────────────
cat << HINT

==> Alpine install complete.

If using extlinux, add or update /boot/extlinux.conf:

  LABEL xanmod
    MENU LABEL XanMod ${KERNEL_VERSION}
    LINUX /boot/vmlinuz-xanmod
    INITRD /boot/initramfs-xanmod
    APPEND root=/dev/sda3 modules=sd-mod,usb-storage,ext4 quiet

Reboot to use kernel ${KERNEL_VERSION}.
HINT

# Install btrfs_dwarfs out-of-tree module if requested
if [[ "${ENABLE_BDFS}" == "1" ]]; then
  echo "  Installing btrfs_dwarfs module..."
  install_bdfs_module "${KERNEL_VERSION}"
fi
