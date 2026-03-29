# profiles/steamdeck.sh — Steam Deck (AMD Van Gogh APU) profile
#
# Targets the Steam Deck LCD (Jupiter) and OLED (Galileo) running a
# non-SteamOS distro (Arch, Bazzite, ChimeraOS, etc.) on XanMod MAIN.
#
# Hardware: AMD Van Gogh (Zen 2 + RDNA 2), 4C/8T @ up to 3.5GHz,
#           16GB LPDDR5, NVMe, MT7921K WiFi/BT, USB-C with DP alt-mode.
#
# Key differences from the desktop profile:
#   - x86-64-v3 (Van Gogh supports AVX2)
#   - AMD vendor config (disables Intel-specific drivers)
#   - steamdeck hardware config fragment (GPU, audio, input, WiFi)
#   - LZ4 swap (16GB RAM fills quickly under gaming load)
#   - No debug (reduces image size, faster boot)
#   - amd-pstate passive mode for better battery life
#
# Usage:
#   ./build.sh --profile steamdeck
#   ./build.sh --profile steamdeck --branch LTS   # for more stable base

BRANCH="${BRANCH:-MAIN}"
MLEVEL="v3"          # Van Gogh supports AVX2 (x86-64-v3)
VENDOR="amd"         # Disable Intel-specific drivers

ENABLE_ROG=0
ENABLE_MEDIATEK_BT=0  # MT7921K BT is upstream in 6.x, no patch needed
ENABLE_FS_PATCHES=0
ENABLE_NET_PATCHES=1  # BBR + nftables useful for gaming/streaming
ENABLE_CACHY=0
ENABLE_PARALLEL_BOOT=0

LZ4_SWAP=1
NO_DEBUG=1

# Merge the Steam Deck hardware config fragment
EXTRA_CONFIG="${EXTRA_CONFIG:-configs/hardware/steamdeck.config}"
