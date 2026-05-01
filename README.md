# XanMod Unified

A distro-agnostic and architecture-agnostic build system for the
[XanMod Linux kernel](https://xanmod.org), consolidating:

- **Kernel source** — [gitlab.com/xanmod/linux](https://gitlab.com/xanmod/linux) (MAIN, EDGE, LTS, RT)
- **Patch sets** — ASUS ROG, MediaTek BT, filesystem, network, scheduler, boot
- **Config fragments** — x86-64 v1–v4, ARM64, RISC-V, feature and hardware overlays
- **Packaging** — Debian/Ubuntu (.deb), Arch Linux (.pkg.tar.zst), Gentoo (ebuild), Fedora/openSUSE (RPM), generic
- **CI** — GitHub Actions + GitLab CI, producing release artifacts for all targets

---

## Quick start

```bash
git clone https://github.com/YOUR_ORG/xanmod-unified
cd xanmod-unified

# Build for your current machine (auto-detects distro, arch, microarch level)
./build.sh

# Build with a named profile
./build.sh --profile desktop
./build.sh --profile rog
./build.sh --profile server --branch LTS
./build.sh --profile rt

# Build a specific branch + microarch level
./build.sh --branch EDGE --mlevel v3

# Build without installing (compile only)
./build.sh --no-install
```

---

## Branches

| Flag | Git branch | Description |
|------|-----------|-------------|
| `MAIN` | `6.19` | Latest stable XanMod (default) |
| `EDGE` | `6.19` | Mainline with experimental patches |
| `LTS` | `6.18` | Long-term support |
| `RT` | `6.18-rt` | PREEMPT_RT real-time |

Branch version numbers are updated in `kernel/fetch.sh` as XanMod cuts new releases.

---

## Profiles

| Profile | Branch | Arch | Key features |
|---------|--------|------|-------------|
| `desktop` | MAIN | x86-64-v3 | Net patches, LZ4 swap, no debug |
| `rog` | MAIN | x86-64-v3 | ROG patches, MediaTek BT, LZ4 swap |
| `server` | LTS | x86-64-v2 | Net patches, no debug |
| `rt` | RT | x86-64-v3 | PREEMPT_RT |
| `arm64` | MAIN | arm64 | LZ4 swap, no debug |

See [`profiles/README.md`](profiles/README.md) for how to write custom profiles.

---

## Feature flags

All flags are environment variables. Set them on the command line or in a profile.

| Variable | Default | Description |
|----------|---------|-------------|
| `BRANCH` | `MAIN` | Kernel branch |
| `MLEVEL` | auto | x86-64 microarch level (v1/v2/v3/v4) |
| `VENDOR` | — | CPU vendor fragment (`amd` or `intel`) |
| `ENABLE_ROG` | `0` | ASUS ROG patches + config |
| `ENABLE_MEDIATEK_BT` | `0` | MediaTek MT7921 BT patches |
| `ENABLE_FS_PATCHES` | `0` | Filesystem patches |
| `ENABLE_NET_PATCHES` | `0` | Network patches |
| `ENABLE_CACHY` | `0` | CachyOS scheduler patch |
| `ENABLE_PARALLEL_BOOT` | `0` | Parallel boot patch |
| `NO_DEBUG` | `0` | Disable debug/tracing overhead |
| `LZ4_SWAP` | `0` | LZ4 compressed swap |
| `EXTRA_CONFIG` | — | Path to an additional .config fragment |
| `JOBS` | `nproc` | Parallel build jobs |
| `FULL_CLONE` | `0` | Full git clone instead of shallow |
| `DO_FETCH` | `1` | Fetch/update kernel source before build |
| `DO_INSTALL` | `1` | Install after build |

---

## Distro support

`build.sh` auto-detects the running distro via `/etc/os-release` and falls
back to package manager detection. Override with `DISTRO=<backend>`.

### Backends

| Backend | Install method | Initramfs tool | Bootloader |
|---------|---------------|----------------|------------|
| `debian` | `make bindeb-pkg` → `dpkg -i` | `update-initramfs` | `update-grub` |
| `arch` | `make pacman-pkg` → `pacman -U` | `mkinitcpio` | `grub-mkconfig` |
| `gentoo` | `make install` + modules | `genkernel` | `grub-mkconfig` |
| `fedora` | `make rpm-pkg` → `dnf install` | `dracut` | `grub2-mkconfig` |
| `opensuse` | `make rpm-pkg` → `zypper install` | `dracut` | `grub2-mkconfig` |
| `alpine` | `make install` + manual copy | `mkinitfs` | `update-extlinux` |
| `void` | `make install` + modules | `dracut` | `grub-mkconfig` |
| `slackware` | `make install` + manual copy | `mkinitrd` | `lilo` / `grub` |
| `generic` | `make install` + modules | auto-detected | auto-detected |

### Distro compatibility matrix

Sourced from [fresh-eggs/SUPPORTED-DISTROS.md](https://github.com/Interested-Deving-1896/fresh-eggs/blob/main/SUPPORTED-DISTROS.md).

#### ✅ Supported via `debian` backend
Debian, Ubuntu, Kubuntu, Xubuntu, Lubuntu, Ubuntu MATE, Ubuntu Studio,
Linux Mint, Zorin OS, Pop!\_OS, elementary OS, KDE neon, Kali Linux,
Parrot OS, Devuan, SparkyLinux, BunsenLabs, Proxmox VE, AnduinOS,
Linuxfx, Voyager, Linux Lite, Q4OS, Bodhi Linux, Peppermint OS,
Feren OS, Rhino Linux, PikaOS, Damn Small Linux, Endless OS,
Emmabuntüs, Kodachi, AV Linux, wattOS, MakuluLinux, BlendOS,
BigLinux, DragonOS, MX Linux, antiX, Tails, deepin ¹,
TUXEDO OS, SDesk, FunOS, Mabox ², Regata ³

> ¹ deepin: `packaging/debian/install.sh` automatically runs
> `deepin-immutable-writable enable` before installing and restores
> immutability on exit.
>
> ² Mabox is Arch-based — detected via `arch` backend, listed here for reference.
>
> ³ Regata is openSUSE-based — detected via `opensuse` backend.

#### ✅ Supported via `arch` backend
Arch Linux, EndeavourOS, Manjaro, CachyOS, Garuda Linux, Bluestar,
RebornOS, Archcraft, ArchBang, Artix Linux, Mabox Linux

#### ✅ Supported via `fedora` backend
Fedora, Nobara, AlmaLinux, Rocky Linux, Red Hat Enterprise Linux,
Oracle Linux, Bazzite, Ultramarine Linux, CentOS

#### ✅ Supported via `opensuse` backend
openSUSE Leap, openSUSE Tumbleweed, Regata OS

#### ✅ Supported via `gentoo` backend
Gentoo, Calculate Linux

#### ✅ Supported via `alpine` backend
Alpine Linux (glibc and musl variants)

#### ✅ Supported via `void` backend
Void Linux (glibc and musl variants)

#### ✅ Supported via `slackware` backend
Slackware, Porteus, AUSTRUMI

#### ⚠️ Partial / manual steps required
| Distro | Reason | Workaround |
|--------|--------|------------|
| Garuda | Uses `garuda-dracut` which conflicts with `mkinitcpio` | Remove `garuda-dracut` first, or use `generic` backend |
| NixOS | Kernels managed declaratively via nixpkgs | Use a Nix overlay (not yet implemented) |
| deepin | Immutable root filesystem | Handled automatically by `packaging/debian/install.sh` |

#### ❌ Not supported
| Distro | Reason |
|--------|--------|
| FreeBSD / GhostBSD / OpenBSD | Not Linux |
| ReactOS / Haiku | Not Linux |
| NixOS | Architecturally incompatible with source-build install |
| Puppy / EasyOS / Tiny Core | Independent base, no standard package manager |
| Chimera Linux | Uses LLVM/clang toolchain; kernel build untested |
| KaOS | Independent base |
| Mageia / OpenMandriva / PCLinuxOS / ALT | Mandrake-based, not tested |
| Solus | Independent base (eopkg) |
| TrueNAS | Appliance OS, not a general-purpose distro |

For Debian/Ubuntu, pre-built `.deb` packages are also available on the
[Releases](../../releases) page for x86-64 (v2, v3) and ARM64.

---

## Architecture support

| Architecture | Status | Notes |
|-------------|--------|-------|
| x86-64 v1–v4 | ✅ Supported | Auto-detected from `/proc/cpuinfo` |
| ARM64 | ⚠️ Experimental | Config in `configs/base/aarch64.config`; no upstream XanMod ARM64 configs exist |
| RISC-V 64 | ⚠️ Experimental | Minimal config; XanMod patches largely untested on RISC-V |

---

## Patch status

Hardware patches from the source repos target kernel 5.16.x and require
rebase before use. The `series` files in each patch directory document
which patches need porting.

| Patch set | Source | Status |
|-----------|--------|--------|
| `patches/hardware/asus-rog/` | arglebargle-arch/xanmod-rog-PKGBUILD | ⚠️ Needs 6.x rebase |
| `patches/hardware/mediatek-bt/` | arglebargle-arch/xanmod-rog-PKGBUILD | ⚠️ Likely upstream in 5.18+ |
| `patches/fs/` | arglebargle-arch/xanmod-rog-PKGBUILD | ⚠️ Needs 6.x rebase |
| `patches/net/` | arglebargle-arch/xanmod-rog-PKGBUILD | ⚠️ Needs 6.x rebase |
| `patches/sched/` | zakuradev/kernel-configuration | ⚠️ cacule removed from XanMod upstream |
| `patches/boot/` | arglebargle-arch/xanmod-rog-PKGBUILD | ⚠️ Needs 6.x rebase |

---

## Repository layout

```
xanmod-unified/
├── build.sh                    Main entry point
├── kernel/
│   ├── fetch.sh                Clone/update gitlab.com/xanmod/linux
│   └── src/                    Kernel source tree (git-ignored)
├── patches/                    Patch sets by category
│   ├── core/                   Applied unconditionally
│   ├── hardware/{asus-rog,mediatek-bt}/
│   ├── fs/  net/  sched/  boot/
│   └── README.md
├── configs/                    Kconfig fragments
│   ├── base/                   Per-arch base configs
│   ├── arch/                   CPU vendor overrides
│   ├── features/               Optional feature fragments
│   └── hardware/               Hardware-specific fragments
├── profiles/                   Named build profiles
│   ├── rog.sh  desktop.sh  server.sh  rt.sh  arm64.sh
│   └── README.md
├── packaging/                  Per-distro install scripts
│   ├── debian/  arch/  gentoo/  rpm/  generic/
├── scripts/
│   └── apply-patches.sh        Patch application driver
├── ci/
│   └── .github/workflows/      GitHub Actions
└── .gitlab-ci.yml              GitLab CI
```

---

## Contributing

1. **Porting patches**: The highest-value contribution right now is rebasing
   the 5.16-era patches in `patches/hardware/asus-rog/` against 6.x and
   verifying upstream merge status for `patches/hardware/mediatek-bt/`.

2. **New distros**: Add `packaging/<distro>/install.sh` and update the
   `detect_distro()` function in `build.sh`.

3. **New profiles**: Add `profiles/<name>.sh` following the existing pattern.

4. **ARM64 configs**: The `configs/base/aarch64.config` is a starting point —
   SoC-specific fragments (Raspberry Pi, Ampere, Apple Silicon via Asahi) are welcome.

---

## License

Build system scripts: MIT.
Kernel source and patches: GPL-2.0 (inherited from Linux).
