#!/usr/bin/env bash
# build.sh — unified XanMod kernel build driver
#
# Usage:
#   ./build.sh [OPTIONS]
#
# Options (all can also be set as environment variables):
#   --branch MAIN|EDGE|LTS|RT   Kernel branch to build (default: MAIN)
#   --profile NAME               Load a named profile from profiles/NAME.sh
#   --mlevel v1|v2|v3|v4        x86-64 microarch level (auto-detected if unset)
#   --vendor amd|intel           CPU vendor config fragment (optional)
#   --jobs N                     Parallel jobs (default: nproc)
#   --no-fetch                   Skip kernel source fetch/update
#   --no-install                 Build only, do not install
#   --help                       Show this message
#
# Feature flags (env vars or set in profile):
#   ENABLE_ROG=1                 Apply ASUS ROG patches + config
#   ENABLE_MEDIATEK_BT=1         Apply MediaTek MT7921 BT patches
#   ENABLE_FS_PATCHES=1          Apply filesystem patches
#   ENABLE_NET_PATCHES=1         Apply network patches
#   ENABLE_CACHY=1               Apply CachyOS scheduler patch
#   ENABLE_PARALLEL_BOOT=1       Apply parallel boot patch
#   NO_DEBUG=1                   Apply no-debug config fragment
#   LZ4_SWAP=1                   Apply LZ4 swap config fragment
#   VENDOR=amd|intel             Apply vendor-specific config fragment
#   EXTRA_CONFIG=path            Merge an additional .config fragment
#   FULL_CLONE=1                 Full git clone instead of shallow

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_SRC="${REPO_ROOT}/kernel/src"
PATCHES_DIR="${REPO_ROOT}/patches"
CONFIGS_DIR="${REPO_ROOT}/configs"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
PACKAGING_DIR="${REPO_ROOT}/packaging"

# ── Defaults ──────────────────────────────────────────────────────────────────
BRANCH="${BRANCH:-MAIN}"
PROFILE="${PROFILE:-}"
JOBS="${JOBS:-$(nproc)}"
DO_FETCH="${DO_FETCH:-1}"
DO_INSTALL="${DO_INSTALL:-1}"
MLEVEL="${MLEVEL:-}"
VENDOR="${VENDOR:-}"
ENABLE_ROG="${ENABLE_ROG:-0}"
ENABLE_MEDIATEK_BT="${ENABLE_MEDIATEK_BT:-0}"
ENABLE_FS_PATCHES="${ENABLE_FS_PATCHES:-0}"
ENABLE_NET_PATCHES="${ENABLE_NET_PATCHES:-0}"
ENABLE_CACHY="${ENABLE_CACHY:-0}"
ENABLE_PARALLEL_BOOT="${ENABLE_PARALLEL_BOOT:-0}"
NO_DEBUG="${NO_DEBUG:-0}"
LZ4_SWAP="${LZ4_SWAP:-0}"
EXTRA_CONFIG="${EXTRA_CONFIG:-}"

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)   BRANCH="${2:?--branch requires a value}";  shift 2 ;;
    --profile)  PROFILE="${2:?--profile requires a value}"; shift 2 ;;
    --mlevel)   MLEVEL="${2:?--mlevel requires a value}";  shift 2 ;;
    --vendor)   VENDOR="${2:?--vendor requires a value}";  shift 2 ;;
    --jobs)     JOBS="${2:?--jobs requires a value}";      shift 2 ;;
    --no-fetch)    DO_FETCH=0;   shift ;;
    --no-install)  DO_INSTALL=0; shift ;;
    --help)
      sed -n '/^# Usage:/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "ERROR: Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── Load profile ───────────────────────────────────────────────────────────────
if [[ -n "${PROFILE}" ]]; then
  PROFILE_FILE="${REPO_ROOT}/profiles/${PROFILE}.sh"
  if [[ ! -f "${PROFILE_FILE}" ]]; then
    echo "ERROR: Profile not found: ${PROFILE_FILE}" >&2
    exit 1
  fi
  # shellcheck source=/dev/null
  source "${PROFILE_FILE}"
  echo "==> Loaded profile: ${PROFILE}"
fi

# ── Detect host architecture ───────────────────────────────────────────────────
detect_arch() {
  local machine
  machine="$(uname -m)"
  case "${machine}" in
    x86_64)          echo "x86" ;;
    aarch64|arm64)   echo "arm64" ;;
    riscv64)         echo "riscv" ;;
    *)
      echo "ERROR: Unsupported host architecture: ${machine}" >&2
      echo "       Cross-compilation: set KARCH and CROSS_COMPILE manually." >&2
      exit 1
      ;;
  esac
}

KARCH="${KARCH:-$(detect_arch)}"
export ARCH="${KARCH}"
export CROSS_COMPILE="${CROSS_COMPILE:-}"

# ── Detect x86-64 microarch level ─────────────────────────────────────────────
detect_mlevel() {
  if [[ "${KARCH}" != "x86" ]]; then
    echo ""
    return
  fi
  local flags
  flags=$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null || echo "")
  if echo "${flags}" | grep -q 'avx512f'; then
    echo "v4"
  elif echo "${flags}" | grep -q 'avx2'; then
    echo "v3"
  elif echo "${flags}" | grep -q 'sse4_2'; then
    echo "v2"
  else
    echo "v1"
  fi
}

[[ -z "${MLEVEL}" ]] && MLEVEL="$(detect_mlevel)"

# ── Detect distro / package manager ───────────────────────────────────────────
detect_distro() {
  if   command -v apt    &>/dev/null; then echo "debian"
  elif command -v pacman &>/dev/null; then echo "arch"
  elif command -v emerge &>/dev/null; then echo "gentoo"
  elif command -v dnf    &>/dev/null; then echo "fedora"
  elif command -v zypper &>/dev/null; then echo "opensuse"
  else                                     echo "generic"
  fi
}

DISTRO="${DISTRO:-$(detect_distro)}"
export DISTRO

# ── RT branch forces rt.config ────────────────────────────────────────────────
[[ "${BRANCH}" == "RT" ]] && ENABLE_RT="${ENABLE_RT:-1}" || ENABLE_RT="${ENABLE_RT:-0}"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==> XanMod Unified Build"
echo "    Branch   : ${BRANCH}"
echo "    Arch     : ${KARCH}${MLEVEL:+ (x86-64-${MLEVEL})}"
echo "    Distro   : ${DISTRO}"
echo "    Jobs     : ${JOBS}"
[[ -n "${PROFILE}" ]] && echo "    Profile  : ${PROFILE}"
[[ -n "${VENDOR}"  ]] && echo "    Vendor   : ${VENDOR}"
echo "    Features :"
[[ "${ENABLE_RT}"            == "1" ]] && echo "               RT (PREEMPT_RT)"
[[ "${ENABLE_ROG}"           == "1" ]] && echo "               ASUS ROG patches"
[[ "${ENABLE_MEDIATEK_BT}"   == "1" ]] && echo "               MediaTek BT patches"
[[ "${ENABLE_FS_PATCHES}"    == "1" ]] && echo "               Filesystem patches"
[[ "${ENABLE_NET_PATCHES}"   == "1" ]] && echo "               Network patches"
[[ "${ENABLE_CACHY}"         == "1" ]] && echo "               CachyOS scheduler"
[[ "${ENABLE_PARALLEL_BOOT}" == "1" ]] && echo "               Parallel boot"
[[ "${NO_DEBUG}"             == "1" ]] && echo "               No-debug"
[[ "${LZ4_SWAP}"             == "1" ]] && echo "               LZ4 swap"
echo ""

# ── Step 1: Fetch kernel source ────────────────────────────────────────────────
if [[ "${DO_FETCH}" == "1" ]]; then
  "${REPO_ROOT}/kernel/fetch.sh" "${BRANCH}"
fi

if [[ ! -d "${KERNEL_SRC}" ]]; then
  echo "ERROR: Kernel source not found at ${KERNEL_SRC}" >&2
  echo "       Run without --no-fetch, or run kernel/fetch.sh first." >&2
  exit 1
fi

# ── Step 2: Apply patches ──────────────────────────────────────────────────────
export ENABLE_ROG ENABLE_MEDIATEK_BT ENABLE_FS_PATCHES \
       ENABLE_NET_PATCHES ENABLE_CACHY ENABLE_PARALLEL_BOOT

"${SCRIPTS_DIR}/apply-patches.sh" "${KERNEL_SRC}" "${PATCHES_DIR}"

# ── Step 3: Merge config fragments ────────────────────────────────────────────
echo "==> Merging config fragments"

MERGE_SCRIPT="${KERNEL_SRC}/scripts/kconfig/merge_config.sh"
if [[ ! -x "${MERGE_SCRIPT}" ]]; then
  echo "ERROR: merge_config.sh not found in kernel source." >&2
  exit 1
fi

# Build the ordered list of fragments
FRAGMENTS=()

# Base: architecture + microarch level
if [[ "${KARCH}" == "x86" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/x86-64-${MLEVEL}.config")
elif [[ "${KARCH}" == "arm64" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/aarch64.config")
elif [[ "${KARCH}" == "riscv" ]]; then
  FRAGMENTS+=("${CONFIGS_DIR}/base/riscv64.config")
fi

# CPU vendor fragment
if [[ -n "${VENDOR}" ]]; then
  VENDOR_CFG="${CONFIGS_DIR}/arch/${VENDOR}.config"
  [[ -f "${VENDOR_CFG}" ]] && FRAGMENTS+=("${VENDOR_CFG}") \
    || echo "WARNING: No vendor config for '${VENDOR}', skipping."
fi

# Feature fragments
FRAGMENTS+=("${CONFIGS_DIR}/features/performance.config")
[[ "${ENABLE_RT}"   == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/features/rt.config")
[[ "${LZ4_SWAP}"    == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/features/lz4-swap.config")
[[ "${NO_DEBUG}"    == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/features/no-debug.config")

# Hardware fragments
[[ "${ENABLE_ROG}"  == "1" ]] && FRAGMENTS+=("${CONFIGS_DIR}/hardware/asus-rog.config")

# User-supplied extra fragment (last — highest priority)
[[ -n "${EXTRA_CONFIG}" && -f "${EXTRA_CONFIG}" ]] && FRAGMENTS+=("${EXTRA_CONFIG}")

echo "    Fragments:"
for f in "${FRAGMENTS[@]}"; do
  echo "      $(basename "${f}")"
done

cd "${KERNEL_SRC}"
"${MERGE_SCRIPT}" -m .config "${FRAGMENTS[@]}"
make -j"${JOBS}" ARCH="${KARCH}" olddefconfig

# ── Step 4: Build ─────────────────────────────────────────────────────────────
echo ""
echo "==> Building kernel (jobs: ${JOBS})"
time make -j"${JOBS}" ARCH="${KARCH}" ${CROSS_COMPILE:+CROSS_COMPILE="${CROSS_COMPILE}"}

# ── Step 5: Install ───────────────────────────────────────────────────────────
if [[ "${DO_INSTALL}" == "1" ]]; then
  echo ""
  echo "==> Installing via packaging/${DISTRO}/install.sh"
  INSTALLER="${PACKAGING_DIR}/${DISTRO}/install.sh"
  if [[ ! -x "${INSTALLER}" ]]; then
    echo "WARNING: No installer for distro '${DISTRO}', falling back to generic."
    INSTALLER="${PACKAGING_DIR}/generic/install.sh"
  fi
  KERNEL_SRC="${KERNEL_SRC}" KARCH="${KARCH}" bash "${INSTALLER}"
fi

echo ""
echo "==> Build complete."
