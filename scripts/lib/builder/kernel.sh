source "${BASH_SOURCE[0]%/*}/os.sh"

# Returns the latest Bodhi build ID for the selected kernel version.
#
# Arguments:
#   Kernel version in the format <major>.<minor> (e.g. "5.19")
# Outputs:
#   Build ID in NEVR[A] format (name-epoch-version-release[-architecture]) (e.g. "kernel-5.19.17-300.fc37")
kernel::build::lookup() {
	local kernel=$1

	local os_version_id
	os_version_id="$(os::version_id)" || return

	local os=f"$os_version_id"

	>&2 echo "Querying Bodhi builds for kernel '${kernel}' and OS '${os}'"

	local buildid=''

	local status
	local -i i
	local line
	local -i return
	local -i num_pages
	local -i num_updates
	local -i page_size=20
	local -i close_body=0
	for status in stable pending testing; do
		num_pages=10
		for i in $(seq 1 "$num_pages"); do
			>&2 echo "Reading results page $(( i )) for status '${status}'"
			# read exits with a non-zero code if the last read input doesn't end
			# with a newline character. The printf without newline that follows the
			# command ensures that the final input not only contains its exit code,
			# but causes read to fail so we can capture the return value.
			# Ref. https://unix.stackexchange.com/a/176703/152409
			while IFS= read -r line || ! return="$line"; do
				if (( close_body )); then
					# read the remaining response body to ensure we don't abort
					# the loop before returning the exit code with printf.
					continue
				fi
				if [[ "$line" =~ (kernel-${kernel//\./\\.}(\.[0-9])?-[0-9]+(\.rc[0-9]+(\.[0-9]+)?)?\.fc${os_version_id}) ]]; then
					>&2 echo "Found matching build ID ${line}"
					buildid="${BASH_REMATCH[1]}"
					close_body=1
					continue
				fi
				if (( i == 1 )) && [[ "$line" =~ ([0-9]+)\ updates\ found ]]; then
					num_updates="${BASH_REMATCH[1]}"
					num_pages=$(( num_updates / page_size ))
					if (( num_pages % page_size )); then
						(( num_pages++ ))
					fi
					>&2 echo "Reading $(( num_pages-1 )) more results pages for status '${status}'"
				fi
			done < <(bodhi updates query \
				--packages=kernel \
				--releases="$os" \
				--status="$status" \
				--content-type=rpm \
				--rows="$page_size" \
				--page="$i"; \
				printf '%s' "$?"
			)
			if (( i >= num_pages )) || [[ -n "$buildid" ]] || (( return )); then
				break
			fi
		done
		if [[ -n "$buildid" ]] || (( return )); then
			break
		fi
	done

	if (( return )); then
		>&2 echo "Failed to look up Bodhi builds for kernel '${kernel}' and OS '${os}'"
		return "$return"
	fi

	if [[ -z "$buildid" ]]; then
		>&2 echo "Couldn't find a Bodhi build for kernel '${kernel}' and OS '${os}'"
		return 1
	fi

	echo "$buildid"
}

# Installs a Bodhi kernel build.
#
# Arguments:
#   Build ID in NEVR[A] format (name-epoch-version-release[-architecture]) (e.g. "kernel-5.19.17-300.fc37")
# Outputs:
#   None
kernel::build::install() {
	local buildid=$1

	local arch
	arch="$(arch)" || return

	local tmpdir
	tmpdir="$(mktemp -d)" || return

	>&2 echo "Downloading kernel build '${buildid}' from Bodhi"

	pushd "$tmpdir" >/dev/null || return
	bodhi updates download \
		--builds="$buildid" \
		--arch="$(arch)" \
		|| return
	popd >/dev/null || return

	local kernel
	kernel="$(kernel::from_buildid "$buildid")" || return

	local -a rpms_candidates=(
		"${tmpdir}/kernel-core-${kernel}.rpm"
		"${tmpdir}/kernel-modules-${kernel}.rpm"
		"${tmpdir}/kernel-modules-core-${kernel}.rpm"
		"${tmpdir}/kernel-devel-${kernel}.rpm"
	)

	local -a rpms
	local rpm
	for rpm in "${rpms_candidates[@]}"; do
		if [[ -f "$rpm" ]]; then
			rpms+=( "$rpm" )
		fi
	done

	dnf install -y "${rpms[@]}" \
	|| rpm -Uvh --oldpackage "${rpms[@]}" \
	|| return

	rm -rf "${tmpdir}"
}

# Returns the kernel version from a Bodhi kernel build ID.
#
# Arguments:
#   Build ID in NEVR[A] format (name-epoch-version-release[-architecture]) (e.g. "kernel-5.19.17-300.fc37")
# Outputs:
#   Kernel version in [NE]VRA format ([name-epoch-]version-release-architecture) (e.g. "5.19.17-300.fc37.x86_64")
kernel::from_buildid() {
	local buildid=$1

	local arch
	arch="$(arch)" || return

	echo "${buildid#kernel-}.${arch}"
}

# Returns the version of the running kernel.
#
# Arguments:
#   None
# Outputs:
#   Kernel version in [NE]VRA format ([name-epoch-]version-release-architecture) (e.g. "5.19.17-300.fc37.x86_64")
kernel::current() {
	local kernel
	kernel="$(uname -r)" || return

	echo "$kernel"
}

# Waits until the selected kernel version is installed.
#
# Arguments:
#   Kernel version in the format <major>.<minor> (e.g. "5.19")
# Outputs:
#   Returns 0 if the package is installed, >0 if the function times out
kernel::wait_installed() {
	local kernel=$1

	local os_version_id arch
	os_version_id="$(os::version_id)" || return
	arch="$(arch)" || return

	local pkg_pattern="kernel-devel-${KERNEL_VERSION}.*.fc${os_version_id}.${arch}"

	local _
	for _ in $(seq 1 20); do
		if dnf list installed "$pkg_pattern"; then
			return 0
		fi
		sleep 3
	done

	return 1
}
