#!/usr/bin/env bash
# scripts/build-bdfs.sh — build the btrfs_dwarfs out-of-tree kernel module
#
# Called by build.sh when ENABLE_BDFS=1. Not intended for direct use.
#
# Arguments:
#   $1  — path to the built kernel source tree (KERNEL_SRC)
#   $2  — path to a btrfs-dwarfs-framework checkout, or the directory where
#          it should be cloned (default: kernel/bdfs-src)
#
# The module .ko is left in $BDFS_SRC/kernel/btrfs_dwarfs/ and is installed
# by the normal packaging/*/install.sh scripts via `make modules_install` on
# the kernel source tree, which picks up external modules registered with
# INSTALL_MOD_PATH.  For out-of-tree installs the install scripts call
# `depmod -a` after copying the .ko into the running kernel's extra/ dir.

set -euo pipefail

KERNEL_SRC="${1:?kernel source path required}"
BDFS_SRC="${2:?btrfs-dwarfs-framework path required}"

BDFS_REPO="https://github.com/Interested-Deving-1896/btrfs-dwarfs-framework.git"

# ── Ensure source is present ──────────────────────────────────────────────────
if [[ ! -d "${BDFS_SRC}/kernel/btrfs_dwarfs" ]]; then
  echo "  Cloning btrfs-dwarfs-framework into ${BDFS_SRC}"
  git clone --depth=1 "${BDFS_REPO}" "${BDFS_SRC}"
fi

# ── Build the kernel module ───────────────────────────────────────────────────
echo "  Building kernel/btrfs_dwarfs against ${KERNEL_SRC}"
make -C "${BDFS_SRC}/kernel" KDIR="${KERNEL_SRC}"

echo "  Module built: ${BDFS_SRC}/kernel/btrfs_dwarfs/btrfs_dwarfs.ko"
