#!/usr/bin/env bash
# scripts/apply-patches.sh — apply patch series to a kernel source tree
#
# Called by build.sh. Not intended for direct use.
#
# Arguments:
#   $1  — path to kernel source tree
#   $2  — path to patches/ directory (default: patches/ relative to repo root)
#
# Environment variables (set by build.sh or profile):
#   ENABLE_ROG=1            apply patches/hardware/asus-rog/
#   ENABLE_MEDIATEK_BT=1    apply patches/hardware/mediatek-bt/
#   ENABLE_FS_PATCHES=1     apply patches/fs/
#   ENABLE_NET_PATCHES=1    apply patches/net/
#   ENABLE_CACHY=1          apply patches/sched/
#   ENABLE_PARALLEL_BOOT=1  apply patches/boot/
#   ENABLE_BDFS=1           (no in-tree patches; module built out-of-tree by build-bdfs.sh)

set -euo pipefail

KERNEL_SRC="${1:?kernel source path required}"
PATCHES_DIR="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/patches}"

apply_series() {
  local series_file="$1"
  local patch_dir
  patch_dir="$(dirname "${series_file}")"

  if [[ ! -f "${series_file}" ]]; then
    return 0
  fi

  while IFS= read -r line; do
    # skip comments and blank lines
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    local patch_path="${patch_dir}/${line}"
    if [[ ! -f "${patch_path}" ]]; then
      echo "WARNING: patch not found, skipping: ${patch_path}" >&2
      continue
    fi

    echo "  Applying: ${line}"
    patch -p1 -d "${KERNEL_SRC}" < "${patch_path}"
  done < "${series_file}"
}

echo "==> Applying patch sets"

echo "  [core]"
apply_series "${PATCHES_DIR}/core/series"

if [[ "${ENABLE_ROG:-0}" == "1" ]]; then
  echo "  [hardware/asus-rog]"
  apply_series "${PATCHES_DIR}/hardware/asus-rog/series"
fi

if [[ "${ENABLE_MEDIATEK_BT:-0}" == "1" ]]; then
  echo "  [hardware/mediatek-bt]"
  apply_series "${PATCHES_DIR}/hardware/mediatek-bt/series"
fi

if [[ "${ENABLE_FS_PATCHES:-0}" == "1" ]]; then
  echo "  [fs]"
  apply_series "${PATCHES_DIR}/fs/series"
fi

if [[ "${ENABLE_NET_PATCHES:-0}" == "1" ]]; then
  echo "  [net]"
  apply_series "${PATCHES_DIR}/net/series"
fi

if [[ "${ENABLE_CACHY:-0}" == "1" ]]; then
  echo "  [sched/cachy]"
  apply_series "${PATCHES_DIR}/sched/series"
fi

if [[ "${ENABLE_PARALLEL_BOOT:-0}" == "1" ]]; then
  echo "  [boot]"
  apply_series "${PATCHES_DIR}/boot/series"
fi

echo "==> Patch application complete"
