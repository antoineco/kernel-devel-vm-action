source "${BASH_SOURCE[0]%/*}/util.sh"

# Generates a Lima instance configuration.
#
# Arguments:
#   Image URL
#   Image SHA256 checksum
#   Machine architecture in the Linux format (e.g. "x86_64")
#   Kernel version in the format <major>.<minor> (e.g. "5.19")
#   Absolute path to workspace
#   Absolute path to scripts
# Outputs:
#   None
lima::config::generate() {
	local img_url=$1
	local img_sha=$2
	local arch=$3
	local kernel=$4
	local workspace=$5
	local scripts_base=$6

	yq '.images = [
		{
			"location": "'"$img_url"'",
			"arch": "'"$arch"'",
			"digest": "sha256:'"$img_sha"'"
		}
	] |
	.mounts += [
		{
			"location": "'"$workspace"'",
			"writable": true
		},
		{
			"location": "'"$scripts_base"'"
		}
	] |
	.env.KERNEL_VERSION = "'"$kernel"'" |
	.env.SCRIPTS_BASE = "'"$scripts_base"'"' \
	"${BASH_SOURCE[0]%/*}"/../../../lima/build.template.yaml \
	>"${BASH_SOURCE[0]%/*}"/../../../lima/build.yaml || return

	local cfg_json
	cfg_json="$(yq -o=json -I0 "${BASH_SOURCE[0]%/*}"/../../../lima/build.yaml)" || return
	>&2 echo "::debug::Generated Lima instance config (compacted): ${cfg_json}"
}

# Bootstraps a new Lima instance from a generated configuration.
#
# Globals:
#   LIMA_INSTANCE
# Arguments:
#   None
# Outputs:
#   None
lima::vm::bootstrap() {
	local -a cmd_args
	if lima::supports_timeout; then
		cmd_args+=( '--timeout=20m' )
	fi

	>&2 echo "Bootstrapping Lima instance '${LIMA_INSTANCE}'"
	limactl start --name="$LIMA_INSTANCE" "${cmd_args[@]}" \
		"${BASH_SOURCE[0]%/*}"/../../../lima/build.yaml
}

# Restarts the Lima instance.
#
# Globals:
#   LIMA_INSTANCE
# Arguments:
#   None
# Outputs:
#   None
lima::vm::restart() {
	>&2 echo "Restarting Lima instance '${LIMA_INSTANCE}'"
	limactl stop "$LIMA_INSTANCE" || return
	sleep 3
	limactl start "$LIMA_INSTANCE"
}

# Destroys the Lima instance.
#
# Globals:
#   LIMA_INSTANCE
# Arguments:
#   (Optional) Name of the Lima instance to destroy. Takes precedence over LIMA_INSTANCE
# Outputs:
#   None
lima::vm::destroy() {
	local instance="$LIMA_INSTANCE"
	if (( $# == 1 )); then
		instance=$1
	fi

	local -i running=0
	running="$(limactl list "$instance" --json \
		| jq -r 'if .status and .status == "Running" then 1 else 0 end'
	)" || return
	if (( running )); then
		>&2 echo "Stopping Lima instance '${instance}'"
		limactl stop "$instance" || return
	fi

	>&2 echo "Destroying Lima instance '${instance}'"
	limactl rm "$instance"
}

# Conditionally creates an additional entry in the Lima image cache by checking
# whether a cache entry for the given image checksum already exists for a
# different URL.
#
# Arguments:
#   Image URL
#   Image SHA256 checksum
# Outputs:
#   None
lima::cache::refresh() {
	local img_url=$1
	local img_sha=$2

	local os
	os="$(uname -s)" || return

	local cache_home
	cache_home="$(util::cache_home)" || return

	>&2 echo "::debug::Current cache home directory is '${cache_home}'"

	[[ -d "$cache_home"/lima/download/by-url-sha256 ]] || return 0

	local urlsum
	urlsum="$(util::sha256sum "$img_url")" || return

	local urldir
	urldir="$cache_home"/lima/download/by-url-sha256/"$urlsum"
	>&2 echo "::debug::The expected cache entry for image URL '${img_url}' is '${urldir##*/}'"
	if [[ -d "$urldir" ]]; then
		>&2 echo "A Lima image cache entry already exists for '${urldir##*/}'"
		return 0
	fi

	local imgsum
	local dir
	for dir in "$cache_home"/lima/download/by-url-sha256/*; do
		>&2 echo "::debug::Evaluating Lima image cache entry '${dir##*/}'"
		[[ -f "$dir"/sha256.digest ]] || continue

		imgsum="$(<"$dir"/sha256.digest)"
		imgsum="${imgsum#sha256:}"

		if [[ "$img_sha" == "$imgsum" ]]; then
			>&2 echo "Cloning Lima image cache entry '${dir##*/}' to '${urldir##*/}'"
			util::cp "$dir" "$urldir" || return
			printf '%s' "$img_url" >"$urldir"/url
			return
		fi
	done
}

# Returns whether the installed Lima version supports the 'timeout' flag.
#
# Arguments:
#   None
# Outputs:
#   Returns 0 if the installed version supports customizable timeout, >0 otherwise
lima::supports_timeout() {
	limactl start --help | grep -q '^\ \+--timeout duration'
}
