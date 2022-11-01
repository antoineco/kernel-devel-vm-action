# Returns the machine architecture in Linux format.
#
# Arguments:
#   None
# Outputs:
#   Machine architecture in the Linux format (e.g. "x86_64")
util::linux_arch() {
	local arch
	arch="$(arch)" || return

	local os
	os="$(uname -s)" || return

	if [[ "$os" == Linux ]]; then
		echo "$arch"
		return
	fi

	case "$arch" in
		arm64)
			echo aarch64
			;;
		*)
			echo x86_64
			;;
	esac
}

# Returns the current user's cache root directory.
# Ref. https://pkg.go.dev/os#UserCacheDir
#
# Arguments:
#   None
# Outputs:
#   Absolute path to the user's cache root directory
util::cache_home() {
	local cache_home="${XDG_CACHE_HOME:-}"

	if [[ -z "$cache_home" ]]; then
		local os
		os="$(uname -s)" || return

		case "$os" in
			Linux)
				cache_home=~/.cache
				;;
			*)
				cache_home=~/Library/Caches
				;;
		esac
	fi

	echo "$cache_home"
}

# Returns the SHA256 checksum of the given argument.
#
# Arguments:
#   Arbitrary string
# Outputs:
#   SHA256 checksum
util::sha256sum() {
	local input=$1

	local os
	os="$(uname -s)" || return

	local cmd
	local -a cmd_args=()

	case "$os" in
		Linux)
			cmd=sha256sum
			cmd_args+=( - )
			;;
		*)
			cmd=shasum
			cmd_args+=( -a256 - )
			;;
	esac

	local sha256sum
	sha256sum="$(printf '%s' "$input" | "$cmd" "${cmd_args[@]}")" || return
	echo "${sha256sum%%\ *}"
}

# Copies a directory.
#
# Arguments:
#   Source directory
#   Destination
# Outputs:
#   None
util::cp() {
	local src=$1
	local dst=$2

	local os
	os="$(uname -s)" || return

	local -a cp_args=()

	case "$os" in
		Linux)
			cp_args+=( -r -p )
			;;
		*)
			cp_args+=( -R -p )
			;;
	esac

	cp "${cp_args[@]}" "$src" "$dst"
}
