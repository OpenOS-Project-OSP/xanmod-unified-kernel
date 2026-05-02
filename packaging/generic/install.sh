#!/usr/bin/env bash
# packaging/generic/install.sh — distro-agnostic kernel install
#
# Installs the built kernel using standard make targets, then regenerates
# the initramfs using whichever tool is available on the system.
#
# Called by build.sh. Environment:
#   KERNEL_SRC   path to kernel source tree (required)
#   KARCH        kernel architecture (required)

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
echo "==> Installing kernel ${KERNEL_VERSION} (generic)"

# Install modules
echo "  Installing modules..."
make -j"$(nproc)" ARCH="${KARCH}" modules_install

# Install kernel image + System.map
echo "  Installing kernel image..."
make ARCH="${KARCH}" install

# Regenerate initramfs — try each tool in order
echo "  Regenerating initramfs..."
if command -v update-initramfs &>/dev/null; then
  update-initramfs -c -k "${KERNEL_VERSION}"
elif command -v mkinitcpio &>/dev/null; then
  mkinitcpio -k "${KERNEL_VERSION}" -g "/boot/initramfs-${KERNEL_VERSION}.img"
elif command -v dracut &>/dev/null; then
  dracut --force "/boot/initramfs-${KERNEL_VERSION}.img" "${KERNEL_VERSION}"
elif command -v genkernel &>/dev/null; then
  genkernel --kernel-config="${KERNEL_SRC}/.config" initramfs
else
  echo "WARNING: No initramfs tool found (update-initramfs/mkinitcpio/dracut/genkernel)."
  echo "         You must regenerate the initramfs manually before rebooting."
fi

# Update bootloader — try each in order
echo "  Updating bootloader..."
if command -v update-grub &>/dev/null; then
  update-grub
elif command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
elif command -v grub2-mkconfig &>/dev/null; then
  grub2-mkconfig -o /boot/grub2/grub.cfg
else
  echo "WARNING: No GRUB tool found. Update your bootloader manually."
fi

# Install btrfs_dwarfs out-of-tree module if requested
if [[ "${ENABLE_BDFS}" == "1" ]]; then
  echo "  Installing btrfs_dwarfs module..."
  install_bdfs_module "${KERNEL_VERSION}"
fi

echo "==> Generic install complete. Reboot to use kernel ${KERNEL_VERSION}."
