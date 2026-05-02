#!/usr/bin/env bash
# packaging/debian/install.sh — Debian/Ubuntu kernel install
#
# Two modes:
#   1. Pre-built: install from deb.xanmod.org APT repo (fast, x86-64 only)
#   2. Source-built: package the compiled tree as a .deb and install it
#
# Mode is selected automatically:
#   - If KERNEL_SRC contains a compiled tree → source-built (.deb)
#   - If called with --apt flag → APT repo mode
#
# Environment:
#   KERNEL_SRC        path to compiled kernel source tree
#   KARCH             kernel architecture
#   XANMOD_VARIANT    apt variant: "" | -edge | -lts | -rt-edge | -rt
#                     (only used in APT mode)

set -euo pipefail

KERNEL_SRC="${KERNEL_SRC:?KERNEL_SRC not set}"
KARCH="${KARCH:?KARCH not set}"
APT_MODE="${1:-}"
ENABLE_BDFS="${ENABLE_BDFS:-0}"
BDFS_SRC="${BDFS_SRC:-}"

# shellcheck source=../lib/install-bdfs.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/packaging/lib/install-bdfs.sh"

# ── Deepin immutable filesystem check ─────────────────────────────────────────
# Deepin Linux uses an immutable root filesystem by default. Installing a
# kernel requires temporarily enabling write access first.
# Detection: /etc/deepin-version exists on Deepin systems.
if [[ -f /etc/deepin-version ]] && command -v deepin-immutable-writable &>/dev/null; then
  echo "==> Deepin Linux detected — enabling writable filesystem"
  deepin-immutable-writable enable || {
    echo "ERROR: Could not enable writable filesystem on Deepin." >&2
    echo "       Run manually: sudo deepin-immutable-writable enable" >&2
    exit 1
  }
  # Register a trap to re-enable immutability after install completes or fails
  trap 'echo "==> Re-enabling Deepin immutable filesystem"; deepin-immutable-writable disable' EXIT
fi

# ── APT mode (pre-built, x86-64 Debian/Ubuntu only) ──────────────────────────
if [[ "${APT_MODE}" == "--apt" ]]; then
  if [[ "${KARCH}" != "x86" ]]; then
    echo "ERROR: APT pre-built packages are only available for x86-64." >&2
    exit 1
  fi

  VARIANT="${XANMOD_VARIANT:-}"
  PACKAGE="linux-xanmod${VARIANT}"

  echo "==> Installing ${PACKAGE} from deb.xanmod.org"

  # Add repo and key if not already present
  if [[ ! -f /etc/apt/sources.list.d/xanmod-kernel.list ]]; then
    echo 'deb http://deb.xanmod.org releases main' \
      | tee /etc/apt/sources.list.d/xanmod-kernel.list
    wget -qO - https://dl.xanmod.org/gpg.key \
      | gpg --dearmor \
      | tee /etc/apt/trusted.gpg.d/xanmod-kernel.gpg > /dev/null
    apt-get update -qq
  fi

  apt-get install -y --no-install-recommends "${PACKAGE}"
  echo "==> APT install complete. Reboot to use the new kernel."
  exit 0
fi

# ── Source-built mode: produce .deb packages ──────────────────────────────────
cd "${KERNEL_SRC}"
KERNEL_VERSION="$(make -s kernelrelease)"
echo "==> Packaging kernel ${KERNEL_VERSION} as .deb"

# bindeb-pkg produces linux-image, linux-headers, linux-libc-dev debs
make -j"$(nproc)" ARCH="${KARCH}" bindeb-pkg

# Debs land one directory above the source tree
DEB_DIR="$(dirname "${KERNEL_SRC}")"
echo "==> Installing generated .deb packages from ${DEB_DIR}"
dpkg -i "${DEB_DIR}"/linux-image-*.deb "${DEB_DIR}"/linux-headers-*.deb 2>/dev/null || true
apt-get install -f -y   # fix any dependency issues

# Install btrfs_dwarfs out-of-tree module if requested
if [[ "${ENABLE_BDFS}" == "1" ]]; then
  echo "  Installing btrfs_dwarfs module..."
  install_bdfs_module "${KERNEL_VERSION}"
fi

echo "==> Debian install complete. Reboot to use kernel ${KERNEL_VERSION}."
