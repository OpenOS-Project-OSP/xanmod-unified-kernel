# XanMod Gentoo Overlay (`::xanmod`)

Provides `sys-kernel/xanmod-sources` for Gentoo, integrating the unified
patch system and Kconfig fragments from this repository.

## Setup

### 1. Add the overlay via eselect-repository

```bash
eselect repository add xanmod git \
  https://github.com/Interested-Deving-1896/xanmod-unified-kernel.git

# Sync only this overlay
emaint sync -r xanmod
```

### 2. Clone the unified build system

The ebuild references the xanmod-unified repo for patches and config fragments.
Clone it to one of the default search paths:

```bash
git clone https://github.com/Interested-Deving-1896/xanmod-unified-kernel.git \
  /usr/local/src/xanmod-unified
```

Or set a custom path in `/etc/portage/env/sys-kernel/xanmod-sources`:

```bash
XANMOD_UNIFIED_ROOT="/path/to/your/clone"
```

### 3. Generate the Manifest

```bash
cd /var/db/repos/xanmod/sys-kernel/xanmod-sources
ebuild xanmod-sources-6.19.ebuild manifest
```

### 4. Install

```bash
# Basic install (x86-64-v3, performance defaults)
emerge sys-kernel/xanmod-sources

# With USE flags
USE="lz4-swap no-debug" emerge sys-kernel/xanmod-sources

# ASUS ROG hardware
USE="rog no-debug lz4-swap" emerge sys-kernel/xanmod-sources

# Steam Deck
USE="steamdeck lz4-swap no-debug" emerge sys-kernel/xanmod-sources
```

## USE flags

| Flag | Default | Description |
|------|---------|-------------|
| `rog` | off | Apply ASUS ROG Kconfig fragment |
| `steamdeck` | off | Apply Steam Deck (Van Gogh) Kconfig fragment |
| `lz4-swap` | off | Enable LZ4 compressed swap |
| `no-debug` | off | Disable debug/tracing overhead |
| `performance` | **on** | Apply performance config fragment |

## Microarch level

Set `XANMOD_MLEVEL` in `/etc/portage/env/sys-kernel/xanmod-sources`:

```bash
# /etc/portage/env/sys-kernel/xanmod-sources
XANMOD_MLEVEL="v3"   # v1, v2, v3, or v4
```

Auto-detection (as in `build.sh`) is not available in the ebuild context —
set this explicitly for your CPU.

## Updating

When XanMod releases a new kernel version, a new ebuild will be added
(e.g. `xanmod-sources-6.20.ebuild`). Run `emaint sync -r xanmod` to pull it.
