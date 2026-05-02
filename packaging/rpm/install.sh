#!/usr/bin/env bash
# packaging/rpm/install.sh — Fedora/openSUSE/RHEL kernel install
#
# Builds an RPM from the compiled source tree using `make rpm-pkg`,
# then installs it with dnf or zypper.
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
echo "==> Packaging kernel ${KERNEL_VERSION} as RPM"

# rpm-pkg produces RPMs under ~/rpmbuild/RPMS/
make -j"$(nproc)" ARCH="${KARCH}" rpm-pkg

RPM_DIR="${HOME}/rpmbuild/RPMS/$(uname -m)"
RPM_FILE=$(find "${RPM_DIR}" -name "kernel-${KERNEL_VERSION}*.rpm" | sort | tail -1)

if [[ -z "${RPM_FILE}" ]]; then
  echo "ERROR: RPM not found after build in ${RPM_DIR}" >&2
  exit 1
fi

echo "==> Installing ${RPM_FILE}"
if command -v dnf &>/dev/null; then
  dnf install -y "${RPM_FILE}"
elif command -v zypper &>/dev/null; then
  zypper install -y "${RPM_FILE}"
elif command -v rpm &>/dev/null; then
  rpm -ivh "${RPM_FILE}"
else
  echo "ERROR: No RPM package manager found (dnf/zypper/rpm)." >&2
  exit 1
fi

# Install btrfs_dwarfs out-of-tree module if requested
if [[ "${ENABLE_BDFS}" == "1" ]]; then
  echo "  Installing btrfs_dwarfs module..."
  install_bdfs_module "${KERNEL_VERSION}"
fi

echo "==> RPM install complete. Reboot to use kernel ${KERNEL_VERSION}."
