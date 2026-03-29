#!/usr/bin/env bash
# kernel/fetch.sh — fetch or update the XanMod kernel source tree
#
# Usage:
#   ./kernel/fetch.sh [BRANCH]
#
# BRANCH values (maps to gitlab.com/xanmod/linux branches):
#   MAIN    — latest stable release (default)
#   EDGE    — latest mainline with experimental patches
#   LTS     — long-term support
#   RT      — PREEMPT_RT real-time variant
#
# The source tree is cloned/updated into kernel/src/.
# Shallow clone (--depth 1) is used by default; set FULL_CLONE=1 for full history.

set -euo pipefail

REPO_URL="https://gitlab.com/xanmod/linux.git"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/src"

# Branch name → git branch mapping
# These track the current active branches on gitlab.com/xanmod/linux.
# Update version numbers here when XanMod cuts a new release series.
declare -A BRANCH_MAP=(
  [MAIN]="6.19"
  [EDGE]="6.19"       # EDGE uses the same base version but a different HEAD
  [LTS]="6.18"
  [RT]="6.18-rt"
)

# EDGE branch note: gitlab.com/xanmod/linux uses the same version number for
# both MAIN and EDGE but they track different patch sets. If the upstream
# branch naming changes (e.g. 6.19-edge), update BRANCH_MAP[EDGE] here.

BRANCH="${1:-MAIN}"
BRANCH="${BRANCH^^}"  # normalize to uppercase

if [[ -z "${BRANCH_MAP[$BRANCH]+_}" ]]; then
  echo "ERROR: Unknown branch '${BRANCH}'. Valid values: ${!BRANCH_MAP[*]}" >&2
  exit 1
fi

GIT_BRANCH="${BRANCH_MAP[$BRANCH]}"
DEPTH_ARGS=("--depth" "1")
[[ "${FULL_CLONE:-0}" == "1" ]] && DEPTH_ARGS=()

echo "==> XanMod kernel fetch"
echo "    Branch : ${BRANCH} (git: ${GIT_BRANCH})"
echo "    Target : ${SRC_DIR}"
echo "    Source : ${REPO_URL}"
echo ""

if [[ -d "${SRC_DIR}/.git" ]]; then
  echo "==> Existing tree found — updating"
  cd "${SRC_DIR}"
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ "${CURRENT_BRANCH}" != "${GIT_BRANCH}" ]]; then
    echo "    Switching from '${CURRENT_BRANCH}' to '${GIT_BRANCH}'"
    git fetch "${DEPTH_ARGS[@]}" origin "${GIT_BRANCH}"
    git checkout "${GIT_BRANCH}"
  fi
  git pull "${DEPTH_ARGS[@]}" origin "${GIT_BRANCH}"
else
  echo "==> Cloning (this will take a while for a full clone)"
  git clone "${DEPTH_ARGS[@]}" \
    --branch "${GIT_BRANCH}" \
    --single-branch \
    "${REPO_URL}" \
    "${SRC_DIR}"
fi

KERNEL_VERSION=$(make -s -C "${SRC_DIR}" kernelversion 2>/dev/null || echo "unknown")
echo ""
echo "==> Done. Kernel version: ${KERNEL_VERSION}"
echo "    Source tree: ${SRC_DIR}"
