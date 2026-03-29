#!/usr/bin/env bash
# packaging/slackware/install.sh — Slackware (and derivatives) kernel install
#
# Covers: Slackware, Porteus, AUSTRUMI, and other pkgtool-based distros.
#
# Slackware's kernel install convention:
#   - Kernel image  → /boot/vmlinuz (symlink) or /boot/vmlinuz-generic-<ver>
#   - Modules       → /lib/modules/<version>/
#   - initrd        → mkinitrd (Slackware's own tool)
#   - Bootloader    → LILO (traditional) or GRUB (modern Slackware setups)
#
# Slackware does not use systemd, dracut, or mkinitcpio. It uses its own
# mkinitrd script and lilo/elilo for bootloading.
#
# Environment:
#   KERNEL_SRC   path to compiled kernel source tree
#   KARCH        kernel architecture

set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?KERNEL_SRC not set}"
KARCH="${KARCH:?KARCH not set}"

cd "${KERNEL_SRC}"
KERNEL_VERSION="$(make -s kernelrelease)"
echo "==> Installing kernel ${KERNEL_VERSION} (Slackware)"

# ── Install modules ────────────────────────────────────────────────────────────
echo "  Installing modules to /lib/modules/${KERNEL_VERSION}..."
make -j"$(nproc)" ARCH="${KARCH}" modules_install

# ── Copy kernel image ──────────────────────────────────────────────────────────
echo "  Copying kernel image..."
case "${KARCH}" in
  x86|x86_64)
    KERNEL_IMAGE="arch/x86/boot/bzImage" ;;
  arm64)
    KERNEL_IMAGE="arch/arm64/boot/Image.gz" ;;
  *)
    KERNEL_IMAGE="vmlinux" ;;
esac

# Slackware naming: vmlinuz-generic-<version> with /boot/vmlinuz symlink
install -Dm644 "${KERNEL_IMAGE}" "/boot/vmlinuz-xanmod-${KERNEL_VERSION}"
install -Dm644 System.map        "/boot/System.map-xanmod-${KERNEL_VERSION}"
install -Dm644 .config           "/boot/config-xanmod-${KERNEL_VERSION}"

# Update /boot/vmlinuz symlink to point to new kernel
ln -sf "vmlinuz-xanmod-${KERNEL_VERSION}" /boot/vmlinuz
ln -sf "System.map-xanmod-${KERNEL_VERSION}" /boot/System.map
echo "  /boot/vmlinuz → vmlinuz-xanmod-${KERNEL_VERSION}"

# ── Generate initrd via mkinitrd ───────────────────────────────────────────────
echo "  Generating initrd via mkinitrd..."
if command -v mkinitrd &>/dev/null; then
  # Detect root filesystem type for mkinitrd -f flag
  ROOT_FS=$(df -T / | awk 'NR==2{print $2}')
  ROOT_DEV=$(df / | awk 'NR==2{print $1}')

  mkinitrd \
    -c \
    -k "${KERNEL_VERSION}" \
    -f "${ROOT_FS}" \
    -r "${ROOT_DEV}" \
    -m "$(find /lib/modules/"${KERNEL_VERSION}"/kernel/drivers/ata/ \
               /lib/modules/"${KERNEL_VERSION}"/kernel/drivers/scsi/ \
          -name '*.ko' -printf '%f\n' 2>/dev/null \
          | sed 's/\.ko//' | tr '\n' ':' | sed 's/:$//')" \
    -o "/boot/initrd-xanmod-${KERNEL_VERSION}.gz" \
    2>/dev/null || \
  mkinitrd \
    -c \
    -k "${KERNEL_VERSION}" \
    -o "/boot/initrd-xanmod-${KERNEL_VERSION}.gz"

  ln -sf "initrd-xanmod-${KERNEL_VERSION}.gz" /boot/initrd.gz
  echo "  /boot/initrd.gz → initrd-xanmod-${KERNEL_VERSION}.gz"
else
  echo "WARNING: mkinitrd not found. Generate initrd manually before rebooting."
fi

# ── Update bootloader ──────────────────────────────────────────────────────────
echo "  Updating bootloader..."
if command -v lilo &>/dev/null && [[ -f /etc/lilo.conf ]]; then
  # LILO — traditional Slackware bootloader
  # Ensure lilo.conf references /boot/vmlinuz and /boot/initrd.gz
  if ! grep -q "image=/boot/vmlinuz" /etc/lilo.conf; then
    cat >> /etc/lilo.conf << LILOCONF

# XanMod kernel added by xanmod-unified
image=/boot/vmlinuz
  root=${ROOT_DEV:-/dev/sda1}
  initrd=/boot/initrd.gz
  label=XanMod-${KERNEL_VERSION}
  read-only
LILOCONF
    echo "  Added XanMod stanza to /etc/lilo.conf"
  fi
  lilo
  echo "  LILO updated."
elif command -v grub-mkconfig &>/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
  echo "  GRUB updated."
else
  echo "WARNING: No bootloader tool found (lilo / grub-mkconfig)."
  echo "         Update /etc/lilo.conf or /boot/grub/grub.cfg manually."
fi

echo ""
echo "==> Slackware install complete. Reboot to use kernel ${KERNEL_VERSION}."
