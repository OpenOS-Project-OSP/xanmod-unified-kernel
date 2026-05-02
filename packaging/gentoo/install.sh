#!/usr/bin/env bash
# packaging/gentoo/install.sh — Gentoo kernel install
#
# Installs a kernel built from source using Gentoo conventions:
#   - modules_install → /lib/modules/
#   - kernel image → /boot/
#   - genkernel for initramfs (if available)
#   - grub-mkconfig for bootloader update
#
# For ebuild-based installation, see packaging/gentoo/xanmod-sources.ebuild.
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
echo "==> Installing kernel ${KERNEL_VERSION} (Gentoo)"

echo "  Installing modules..."
make -j"$(nproc)" ARCH="${KARCH}" modules_install

echo "  Installing kernel image..."
# On Gentoo, /boot is typically a separate partition — ensure it's mounted
if ! mountpoint -q /boot 2>/dev/null; then
  echo "WARNING: /boot does not appear to be mounted. Proceeding anyway."
fi
make ARCH="${KARCH}" install

echo "  Regenerating initramfs via genkernel..."
if command -v genkernel &>/dev/null; then
  genkernel \
    --kernel-config="${KERNEL_SRC}/.config" \
    --no-menuconfig \
    --no-clean \
    initramfs
else
  echo "WARNING: genkernel not found. Install sys-kernel/genkernel or regenerate manually."
fi

echo "  Updating GRUB..."
if command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
else
  echo "WARNING: grub-mkconfig not found. Update your bootloader manually."
fi

# Install btrfs_dwarfs out-of-tree module if requested
if [[ "${ENABLE_BDFS}" == "1" ]]; then
  echo "  Installing btrfs_dwarfs module..."
  install_bdfs_module "${KERNEL_VERSION}"
fi

echo "==> Gentoo install complete. Reboot to use kernel ${KERNEL_VERSION}."
