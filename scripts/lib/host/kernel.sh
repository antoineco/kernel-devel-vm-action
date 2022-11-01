source "${BASH_SOURCE[0]%/*}/util.sh"

# Returns the version of the kernel running inside the builder instance.
#
# Globals:
#   LIMA_INSTANCE
# Arguments:
#   None
# Outputs:
#   Kernel version in [NE]VRA format ([name-epoch-]version-release-architecture) (e.g. "5.19.17-300.fc37.x86_64")
kernel::current() {
	local kernelv
	kernelv="$(lima uname -r)" || return

	echo "$kernelv"
}

# Returns the version of the latest kernel installed inside the builder instance.
#
# Globals:
#   LIMA_INSTANCE
# Arguments:
#   None
# Outputs:
#   Kernel version in [NE]VRA format ([name-epoch-]version-release-architecture) (e.g. "5.19.17-300.fc37.x86_64")
kernel::installed() {
	local arch kernelrpm
	arch="$(util::linux_arch)" || return
	kernelrpm="$(lima rpm -q "kernel-devel.${arch}" | tail -n1)" || return

	echo "${kernelrpm#kernel-devel-}"
}
