# Returns the version ID of the current OS.
#
# Arguments:
#   None
# Outputs:
#   OS version ID (e.g. "37")
os::version_id() {
	local os_version_id
	os_version_id="$(. /etc/os-release && echo "$VERSION_ID")" || return

	echo "$os_version_id"
}

# Returns whether an OS package is installed.
#
# Arguments:
#   Package in NEVRA format (name-epoch-version-release-architecture) (e.g. "kernel-5.19.17-300.fc37.x86_64")
# Outputs:
#   Returns 0 if the package is installed, >0 otherwise
os::is_installed() {
	local pkg=$1

	rpm -q "$pkg" >/dev/null || return
}

# Sets the default kernel to boot on.
#
# Arguments:
#   Kernel version in [NE]VRA format ([name-epoch-]version-release-architecture) (e.g. "5.19.17-300.fc37.x86_64")
# Outputs:
#   None
os::bootloader::set_default() {
	local kernel=$1

	local entry

	local cfg
	for cfg in /boot/loader/entries/*.conf; do
		if [[ "$cfg" =~ \/.+-${kernel//\./\\.}\.conf ]]; then
			>&2 echo "Found matching bootloader entry ${cfg}"
			entry="$cfg"
			break
		fi
	done

	if [[ -z "$entry" ]]; then
		>&2 echo "Couldn't find a bootloader entry matching kernel '${kernel}'"
		return 1
	fi

	local entry_title

	local line
	while IFS= read -r line; do
		if [[ "$line" =~ ^title\ (.+) ]]; then
			entry_title="${BASH_REMATCH[1]}"
			break
		fi
	done < "$entry"

	>&2 echo "Setting default bootloader entry to '${entry_title}'"

	grub2-set-default "$entry_title" || return
	grub2-mkconfig -o /etc/grub2.cfg
}

# Waits until the OS has a bootloader entry for a particular kernel.
#
# Arguments:
#   Kernel version in the format <major>.<minor> (e.g. "5.19")
# Outputs:
#   Returns 0 if the bootloader has the desired entry, >0 if the function times out
os::bootloader::wait_entry() {
	local kernel=$1

	local cfg

	local _
	for _ in $(seq 1 20); do
		for cfg in $(sudo sh -c 'ls /boot/loader/entries/*.conf'); do
			if [[ "$cfg" =~ \/.+-${kernel//\./\\.}\..+\.conf ]]; then
				echo "$cfg"
				return 0
			fi
		done
		>&2 echo "No bootloader entry for kernel ${kernel}"
		sleep 3
	done

	return 1
}
