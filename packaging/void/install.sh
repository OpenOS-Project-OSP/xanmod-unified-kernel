#!/usr/bin/env bash
# packaging/void/install.sh — Void Linux kernel install
#
# Void Linux is an independent distro using xbps (package manager) and
# runit (init system). It ships in two variants:
#   - glibc  (default, most common)
#   - musl   (smaller, stricter)
#
# Kernel install uses dracut for initramfs and either grub or
# grub-btrfs depending on the filesystem. The xbps-src build system
# can produce native packages, but for a source-built kernel we use
# make install + dracut directly.
#
# Environment:
#   KERNEL_SRC   path to compiled kernel source tree
#   KARCH        kernel architecture

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
echo "==> Installing kernel ${KERNEL_VERSION} (Void Linux)"

# ── Detect musl vs glibc variant ──────────────────────────────────────────────
if xbps-query -l 2>/dev/null | grep -q 'musl'; then
  VOID_VARIANT="musl"
else
  VOID_VARIANT="glibc"
fi
echo "  Void variant: ${VOID_VARIANT}"

# ── Install modules ────────────────────────────────────────────────────────────
echo "  Installing modules..."
make -j"$(nproc)" ARCH="${KARCH}" modules_install

# ── Install kernel image ───────────────────────────────────────────────────────
# Void uses /boot/vmlinuz-<version> naming (same as generic)
echo "  Installing kernel image..."
make ARCH="${KARCH}" install

# ── Generate initramfs via dracut ──────────────────────────────────────────────
# Void ships dracut by default; mkinitcpio is not standard on Void.
echo "  Generating initramfs via dracut..."
if command -v dracut &>/dev/null; then
  dracut \
    --force \
    --kver "${KERNEL_VERSION}" \
    --compress zstd \
    "/boot/initramfs-${KERNEL_VERSION}.img"
else
  echo "ERROR: dracut not found. Install it: xbps-install -S dracut" >&2
  exit 1
fi

# ── Update bootloader ──────────────────────────────────────────────────────────
echo "  Updating bootloader..."
if command -v update-grub &>/dev/null; then
  update-grub
elif command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
else
  echo "WARNING: grub-mkconfig not found."
  echo "         If using grub: xbps-install -S grub && grub-mkconfig -o /boot/grub/grub.cfg"
  echo "         If using efistub or another bootloader, update it manually."
fi

# ── runit service note ─────────────────────────────────────────────────────────
# runit does not require any kernel-specific service configuration.
# The kernel is loaded by the bootloader before runit starts.

echo ""
# Install btrfs_dwarfs out-of-tree module if requested
if [[ "${ENABLE_BDFS}" == "1" ]]; then
  echo "  Installing btrfs_dwarfs module..."
  install_bdfs_module "${KERNEL_VERSION}"
fi

echo "==> Void Linux install complete. Reboot to use kernel ${KERNEL_VERSION}."
echo "    Variant: ${VOID_VARIANT}"
