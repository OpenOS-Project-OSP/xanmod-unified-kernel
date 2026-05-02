# profiles/rog.sh — ASUS ROG laptop profile
#
# Targets ASUS ROG laptops running XanMod MAIN on x86-64-v3 hardware.
# Enables all ROG-specific patches and config fragments, MediaTek BT,
# LZ4 swap, and disables debug overhead.
#
# Patch rebase status: patches/hardware/asus-rog/series must be populated
# with 6.x-rebased patches before this profile is fully functional.
# See patches/hardware/asus-rog/series for the list of patches to port.
#
# Usage:
#   ./build.sh --profile rog
#   ./build.sh --profile rog --branch EDGE   # track EDGE instead

BRANCH="${BRANCH:-MAIN}"
MLEVEL="${MLEVEL:-v3}"

# ROG hardware patches + Kconfig fragment
ENABLE_ROG=1

# MediaTek MT7921 Bluetooth (common in ROG laptops)
ENABLE_MEDIATEK_BT=1

# Filesystem patches (btrfs autodefrag fix)
ENABLE_FS_PATCHES=1

# Network patches (UDP IPv6 optimisations)
ENABLE_NET_PATCHES=1

# Parallel boot
ENABLE_PARALLEL_BOOT=1

# LZ4 compressed swap — good for RAM-constrained gaming sessions
LZ4_SWAP=1

# Strip debug symbols — reduces image size, speeds up boot
NO_DEBUG=1

# CachyOS scheduler — disabled by default (conflicts with upstream XanMod direction)
# Set ENABLE_CACHY=1 on the command line to override.
ENABLE_CACHY="${ENABLE_CACHY:-0}"

# BTRFS+DwarFS framework — opt-in; requires btrfs-dwarfs-framework source
# Set ENABLE_BDFS=1 on the command line or in a local override to enable.
ENABLE_BDFS="${ENABLE_BDFS:-0}"
