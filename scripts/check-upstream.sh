#!/usr/bin/env bash
# scripts/check-upstream.sh — check whether a patch is already in the kernel tree
#
# Usage:
#   ./scripts/check-upstream.sh <patch-file> [patch-file ...]
#   ./scripts/check-upstream.sh patches/hardware/asus-rog/002-rog-x13-tablet-mode.patch
#   ./scripts/check-upstream.sh patches/fs/*.patch
#
# Requires: kernel source tree at kernel/src/ (run kernel/fetch.sh first)
#
# Exit codes:
#   0  all patches checked (individual results printed per patch)
#   1  kernel source not found
#   2  no patch files given

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_SRC="${REPO_ROOT}/kernel/src"

# ── Colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

# ── Preflight ─────────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <patch-file> [patch-file ...]" >&2
  exit 2
fi

if [[ ! -d "${KERNEL_SRC}/.git" ]]; then
  echo -e "${RED}ERROR:${RESET} Kernel source not found at ${KERNEL_SRC}" >&2
  echo "       Run ./kernel/fetch.sh first." >&2
  exit 1
fi

KERNEL_VERSION=$(make -s -C "${KERNEL_SRC}" kernelversion 2>/dev/null || echo "unknown")
echo -e "${BOLD}Kernel tree:${RESET} ${KERNEL_SRC} (${KERNEL_VERSION})"
echo ""

# ── Per-patch check ───────────────────────────────────────────────────────────
check_patch() {
  local patch_file="$1"
  local result="UNKNOWN"
  local detail=""

  if [[ ! -f "${patch_file}" ]]; then
    echo -e "  ${RED}NOT FOUND:${RESET} ${patch_file}"
    return
  fi

  echo -e "${BOLD}Checking:${RESET} ${patch_file}"

  # 1. Extract subject line from patch header
  local subject
  subject=$(grep -m1 '^Subject:' "${patch_file}" 2>/dev/null \
    | sed 's/^Subject:[[:space:]]*//' \
    | sed 's/\[PATCH[^]]*\][[:space:]]*//' \
    | tr -d '\r')

  # 2. Extract first meaningful function/symbol changed (from diff --git lines)
  local changed_files
  changed_files=$(grep '^diff --git' "${patch_file}" 2>/dev/null \
    | sed 's|diff --git a/||' | awk '{print $1}' | head -5)

  # 3. Check UPSTREAM STATUS line in patch header (our own annotation)
  local upstream_status
  upstream_status=$(grep -i '^UPSTREAM STATUS:' "${patch_file}" 2>/dev/null \
    | head -1 | sed 's/^UPSTREAM STATUS:[[:space:]]*//')

  if [[ -n "${upstream_status}" ]]; then
    echo -e "  ${CYAN}Annotated:${RESET} ${upstream_status}"
  fi

  # 4. Try dry-run apply to see if patch applies cleanly
  local apply_result
  if patch -p1 --dry-run -d "${KERNEL_SRC}" \
       < "${patch_file}" &>/dev/null; then
    apply_result="APPLIES_CLEAN"
  else
    apply_result="DOES_NOT_APPLY"
  fi

  # 5. Search git log for subject keywords
  local git_match=""
  if [[ -n "${subject}" ]]; then
    # Use first 6+ words of subject for search to avoid false positives
    local search_term
    search_term=$(echo "${subject}" | awk '{for(i=1;i<=NF&&i<=8;i++) printf $i" "; print ""}' | sed 's/[[:space:]]*$//')
    git_match=$(git -C "${KERNEL_SRC}" log --oneline --all \
      --grep="${search_term}" 2>/dev/null | head -3)
  fi

  # 6. Search for key symbols from changed files in git log
  local symbol_match=""
  if [[ -z "${git_match}" && -n "${changed_files}" ]]; then
    local first_file
    first_file=$(echo "${changed_files}" | head -1)
    local basename_file
    basename_file=$(basename "${first_file}" .c)
    symbol_match=$(git -C "${KERNEL_SRC}" log --oneline --all \
      --grep="${basename_file}" 2>/dev/null | head -3)
  fi

  # ── Interpret results ──────────────────────────────────────────────────────
  echo -e "  Subject    : ${subject:-<not found>}"
  echo -e "  Dry-run    : ${apply_result}"

  if [[ "${apply_result}" == "DOES_NOT_APPLY" ]]; then
    if [[ -n "${git_match}" ]]; then
      result="UPSTREAM"
      detail="Patch does not apply — likely already merged"
      echo -e "  Git match  :"
      echo "${git_match}" | while read -r line; do
        echo -e "               ${CYAN}${line}${RESET}"
      done
    else
      result="NEEDS_REBASE"
      detail="Patch does not apply and no git match found — needs rebase or already upstream with different context"
    fi
  elif [[ "${apply_result}" == "APPLIES_CLEAN" ]]; then
    if [[ -n "${git_match}" ]]; then
      result="DUPLICATE_RISK"
      detail="Patch applies cleanly but git log matches found — verify it isn't already applied"
      echo -e "  Git match  :"
      echo "${git_match}" | while read -r line; do
        echo -e "               ${YELLOW}${line}${RESET}"
      done
    else
      result="APPLICABLE"
      detail="Patch applies cleanly, no upstream match found"
    fi
  fi

  # ── Print verdict ──────────────────────────────────────────────────────────
  case "${result}" in
    UPSTREAM)
      echo -e "  ${GREEN}Result     : UPSTREAM — already in kernel tree${RESET}"
      ;;
    APPLICABLE)
      echo -e "  ${GREEN}Result     : APPLICABLE — can be applied${RESET}"
      ;;
    NEEDS_REBASE)
      echo -e "  ${YELLOW}Result     : NEEDS REBASE — does not apply cleanly${RESET}"
      ;;
    DUPLICATE_RISK)
      echo -e "  ${YELLOW}Result     : VERIFY — applies but upstream match exists${RESET}"
      ;;
    *)
      echo -e "  ${RED}Result     : UNKNOWN${RESET}"
      ;;
  esac
  [[ -n "${detail}" ]] && echo -e "  Detail     : ${detail}"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
for patch_file in "$@"; do
  check_patch "${patch_file}"
done
