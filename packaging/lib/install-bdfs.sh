#!/usr/bin/env bash
# packaging/lib/install-bdfs.sh — install the btrfs_dwarfs out-of-tree module
#
# Sourced by per-distro install.sh scripts when ENABLE_BDFS=1.
# Must be called after the kernel modules have been installed so that the
# target module directory already exists.
#
# Globals used:
#   KERNEL_VERSION   running kernel release string (from `make kernelrelease`)
#   BDFS_SRC         path to btrfs-dwarfs-framework checkout
#   INSTALL_MOD_PATH optional prefix (default: /)

install_bdfs_module() {
  local kernel_version="${1:?kernel_version required}"
  local bdfs_src="${BDFS_SRC:-}"
  local mod_path="${INSTALL_MOD_PATH:-}"

  if [[ -z "${bdfs_src}" ]]; then
    echo "WARNING: BDFS_SRC not set, skipping btrfs_dwarfs module install." >&2
    return 0
  fi

  local ko="${bdfs_src}/kernel/btrfs_dwarfs/btrfs_dwarfs.ko"
  if [[ ! -f "${ko}" ]]; then
    echo "WARNING: btrfs_dwarfs.ko not found at ${ko}, skipping install." >&2
    return 0
  fi

  local dest="${mod_path}/lib/modules/${kernel_version}/extra"
  echo "  Installing btrfs_dwarfs.ko → ${dest}/"
  install -D -m 644 "${ko}" "${dest}/btrfs_dwarfs.ko"
  depmod -a "${kernel_version}" 2>/dev/null || true
}
