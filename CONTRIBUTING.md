# Contributing

## What needs work

The highest-value contributions right now, in priority order:

1. **Porting patches to 6.x** — `patches/hardware/asus-rog/002-rog-x13-tablet-mode.patch` and the boot patches need rebase against current 6.x kernel structure.
2. **ARM64 SoC configs** — `configs/base/aarch64.config` is a generic starting point. SoC-specific fragments (Raspberry Pi, Ampere, Apple Silicon via Asahi) are welcome under `configs/hardware/`.
3. **New distro packaging** — add `packaging/<distro>/install.sh` for any distro not yet covered.
4. **New profiles** — add `profiles/<name>.sh` for common hardware/use-case combinations.

---

## Porting a patch to 6.x

### 1. Check upstream status first

Before spending time rebasing, verify the patch isn't already in 6.x mainline:

```bash
# Search the kernel git log for the patch subject or a key function name
git -C kernel/src log --oneline --all | grep -i "keyword"

# Or check via web
# https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/log/
```

If the patch is already upstream, mark it as such in the `series` file comment and move on.

### 2. Attempt a clean apply

```bash
# Fetch the kernel source first
./kernel/fetch.sh MAIN

# Try applying the patch
patch -p1 --dry-run -d kernel/src < patches/hardware/asus-rog/002-rog-x13-tablet-mode.patch
```

### 3. Rebase if it doesn't apply cleanly

```bash
cd kernel/src

# Create a working branch
git checkout -b rebase-rog-x13

# Apply with fuzz tolerance to see what fails
patch -p1 -F3 < ../../patches/hardware/asus-rog/002-rog-x13-tablet-mode.patch

# Fix rejected hunks manually, then update the patch
git diff > ../../patches/hardware/asus-rog/002-rog-x13-tablet-mode.patch
```

### 4. Update the series file

Uncomment the patch filename in the relevant `series` file and update the status comment.

### 5. Test

```bash
ENABLE_ROG=1 ./build.sh --no-install
```

---

## Adding a config fragment

Config fragments use standard Kconfig syntax. Each line must be one of:

```
CONFIG_FOO=y
CONFIG_FOO=m
CONFIG_FOO=n
CONFIG_FOO=1234
CONFIG_FOO="string"
# CONFIG_FOO is not set
# comment line
```

Place the fragment in the appropriate directory:

| Directory | Purpose |
|-----------|---------|
| `configs/base/` | Architecture baseline (one per arch/level) |
| `configs/arch/` | CPU vendor overrides |
| `configs/features/` | Optional feature sets |
| `configs/hardware/` | Hardware-specific options |

The lint CI validates fragment syntax on every PR.

---

## Adding a packaging backend

1. Create `packaging/<distro>/install.sh`
2. The script receives `KERNEL_SRC` and `KARCH` as environment variables
3. It should install modules, the kernel image, regenerate initramfs, and update the bootloader
4. Add distro detection to the `detect_distro()` function in `build.sh`

Use `packaging/generic/install.sh` as a reference implementation.

---

## Adding a profile

1. Create `profiles/<name>.sh`
2. Set only the variables your profile needs — unset variables inherit `build.sh` defaults
3. Document the target hardware/use-case in a comment at the top
4. Add an entry to the profile table in `profiles/README.md` and `README.md`

---

## Pull request checklist

- [ ] `bash -n` passes on all modified `.sh` files
- [ ] `shellcheck` passes (run `shellcheck --severity=warning <file>.sh`)
- [ ] Config fragments pass syntax validation (run the lint CI or check manually)
- [ ] Patch `series` files only reference files that exist in the same directory
- [ ] Commit message describes *what* changed and *why*, not *how*

---

## Commit message format

Follow the existing style:

```
subsystem: short description of change

Longer explanation if needed. Reference upstream commits or issues.
```

Examples:
```
patches/asus-rog: rebase 002-rog-x13-tablet-mode against 6.19
configs/aarch64: remove CONFIG_ARM64_ERRATUM_1024718 (removed in 6.1)
profiles: add steamdeck profile
packaging/fedora: add dnf-based installer
```
