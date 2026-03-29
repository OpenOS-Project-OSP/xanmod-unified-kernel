# Self-Hosted Runner Setup

The `build-selfhosted.yml` workflow produces actual kernel packages (.deb,
.pkg.tar.zst, .rpm) and requires a machine with enough resources to complete
a kernel compile. GitHub's free runners time out before a kernel build finishes.

## Minimum requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU cores | 4 | 8–16 |
| RAM | 8 GB | 16–32 GB |
| Disk (free) | 30 GB | 60 GB |
| OS | Any Linux | Debian/Ubuntu or Arch |

A kernel build with `make -j$(nproc)` on 8 cores takes roughly 20–40 minutes
depending on the config. The source tree + build artifacts use ~15 GB.

---

## Register a runner

### 1. Get the registration token

Go to your repository on GitHub:
**Settings → Actions → Runners → New self-hosted runner**

Select **Linux** and your architecture (x86-64 or ARM64).
Copy the token shown — it expires after 1 hour.

### 2. Install the runner agent

```bash
# Create a dedicated user (recommended)
sudo useradd -m -s /bin/bash github-runner
sudo su - github-runner

# Download the runner (check https://github.com/actions/runner/releases for latest)
mkdir actions-runner && cd actions-runner
curl -sL https://github.com/actions/runner/releases/download/v2.317.0/actions-runner-linux-x64-2.317.0.tar.gz \
  | tar xz

# Configure (replace TOKEN and REPO_URL)
./config.sh \
  --url https://github.com/Interested-Deving-1896/xanmod-unified-kernel \
  --token YOUR_TOKEN_HERE \
  --name "$(hostname)-x86-64" \
  --labels "self-hosted,x86-64,linux" \
  --work "_work" \
  --unattended
```

For ARM64 runners, change the download URL to `actions-runner-linux-arm64-*.tar.gz`
and use `--labels "self-hosted,arm64,linux"`.

### 3. Install as a systemd service

```bash
# Still as github-runner user, from the actions-runner directory
sudo ./svc.sh install github-runner
sudo ./svc.sh start
sudo ./svc.sh status
```

### 4. Install kernel build dependencies

```bash
# Debian/Ubuntu
sudo apt-get install -y build-essential bc bison flex libssl-dev \
  libelf-dev libncurses-dev dwarves pahole cpio zstd lz4 git

# Arch Linux
sudo pacman -S --needed base-devel bc bison flex openssl libelf \
  pahole cpio zstd lz4 git

# Fedora
sudo dnf install -y gcc make bc bison flex openssl-devel \
  elfutils-libelf-devel ncurses-devel dwarves pahole cpio zstd lz4 git
```

---

## Trigger a build

Once the runner is registered and online, trigger a build from the GitHub UI:

**Actions → Build (self-hosted) → Run workflow**

Or via the GitHub CLI:

```bash
gh workflow run build-selfhosted.yml \
  --field branch=MAIN \
  --field mlevel=v3 \
  --field profile=desktop \
  --field upload_release=false
```

---

## Multiple runners

To build x86-64 and ARM64 simultaneously, register one runner per architecture
with the appropriate label. The workflow selects the runner via:

```yaml
runs-on:
  - self-hosted
  - ${{ inputs.arch == 'arm64' && 'arm64' || 'x86-64' }}
```

---

## Security considerations

- Self-hosted runners execute arbitrary code from the repository. Only use
  them with **private repositories** or repositories where you control all
  contributors, unless you fully trust all PRs.
- For public repositories, restrict the `build-selfhosted.yml` workflow to
  run only on protected branches or require manual approval for external PRs:
  **Settings → Actions → General → Fork pull request workflows**
- The runner user needs `sudo` access only for `apt-get install` / `pacman -S`.
  Consider pre-installing all dependencies and removing sudo access from the
  runner user after setup.

---

## Caching the kernel source

The kernel source tree (~2 GB shallow clone) is re-fetched on every run by
default. To cache it between runs, add a persistent work directory:

```bash
# In config.sh, set --work to a persistent path outside the runner directory
./config.sh ... --work /var/lib/github-runner/work
```

Then set `FULL_CLONE=0` (default) and `DO_FETCH=1` (default) — `fetch.sh`
will `git pull` the existing tree rather than re-cloning.
