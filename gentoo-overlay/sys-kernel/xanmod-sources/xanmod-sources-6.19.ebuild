# Copyright 2024-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit kernel-build toolchain-funcs

DESCRIPTION="XanMod patched Linux kernel sources"
HOMEPAGE="https://xanmod.org https://gitlab.com/xanmod/linux"

# Upstream XanMod version
XANMOD_PV="${PV}-xanmod1"

# Fetch vanilla kernel tarball from kernel.org; XanMod patches are applied
# from the unified patch system in this repository.
SRC_URI="
	https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${PV}.tar.xz
"

S="${WORKDIR}/linux-${PV}"

LICENSE="GPL-2"
SLOT="${PV}"
KEYWORDS="~amd64 ~arm64"

# USE flags map to build.sh feature flags
IUSE="
	rog
	steamdeck
	lz4-swap
	no-debug
	+performance
"

REQUIRED_USE="
	steamdeck? ( !rog )
"

BDEPEND="
	sys-devel/bc
	sys-devel/bison
	sys-devel/flex
	dev-libs/openssl
	app-arch/lz4
	sys-devel/pahole
	virtual/libelf
"

# Path to the unified build system (this repo, checked out alongside the overlay)
# Adjust XANMOD_UNIFIED_ROOT if your checkout is elsewhere.
XANMOD_UNIFIED_ROOT="${PORTAGE_CONFIGROOT}/etc/portage/xanmod-unified"

_get_unified_root() {
	# Try common locations in order
	local candidates=(
		"${XANMOD_UNIFIED_ROOT}"
		"/usr/local/src/xanmod-unified"
		"/opt/xanmod-unified"
	)
	for d in "${candidates[@]}"; do
		[[ -f "${d}/build.sh" ]] && echo "${d}" && return
	done
	die "xanmod-unified repo not found. Set XANMOD_UNIFIED_ROOT or clone to /usr/local/src/xanmod-unified"
}

src_prepare() {
	local unified_root
	unified_root="$(_get_unified_root)"

	einfo "Using xanmod-unified at: ${unified_root}"

	# Apply patch sets via the unified apply-patches.sh
	local env_vars=(
		ENABLE_ROG=$(usex rog 1 0)
		ENABLE_MEDIATEK_BT=0
		ENABLE_FS_PATCHES=0
		ENABLE_NET_PATCHES=0
		ENABLE_CACHY=0
		ENABLE_PARALLEL_BOOT=0
	)

	env "${env_vars[@]}" \
		bash "${unified_root}/scripts/apply-patches.sh" \
		"${S}" "${unified_root}/patches" \
		|| die "patch application failed"

	# Build ordered config fragment list
	local arch
	arch=$(tc-arch-kernel)
	local fragments=()

	case "${arch}" in
		x86)
			# Default to v3; users can override via /etc/portage/env
			local mlevel="${XANMOD_MLEVEL:-v3}"
			fragments+=( "${unified_root}/configs/base/x86-64-${mlevel}.config" )
			;;
		arm64)
			fragments+=( "${unified_root}/configs/base/aarch64.config" )
			;;
		*)
			die "Unsupported architecture: ${arch}"
			;;
	esac

	use performance  && fragments+=( "${unified_root}/configs/features/performance.config" )
	use lz4-swap     && fragments+=( "${unified_root}/configs/features/lz4-swap.config" )
	use no-debug     && fragments+=( "${unified_root}/configs/features/no-debug.config" )
	use rog          && fragments+=( "${unified_root}/configs/hardware/asus-rog.config" )
	use steamdeck    && fragments+=( "${unified_root}/configs/hardware/steamdeck.config" )

	# Merge fragments into .config
	einfo "Merging config fragments:"
	for f in "${fragments[@]}"; do
		einfo "  $(basename "${f}")"
	done

	"${S}/scripts/kconfig/merge_config.sh" \
		-m "${S}/.config" "${fragments[@]}" \
		|| die "merge_config.sh failed"

	kernel-build_src_prepare
}

pkg_postinst() {
	kernel-build_pkg_postinst

	elog ""
	elog "XanMod kernel ${PV} installed."
	elog ""
	elog "To set the x86-64 microarch level (default: v3), add to"
	elog "/etc/portage/env/sys-kernel/xanmod-sources:"
	elog "  XANMOD_MLEVEL=v2   # for older CPUs"
	elog "  XANMOD_MLEVEL=v4   # for AVX-512 CPUs"
}
