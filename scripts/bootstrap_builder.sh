#!/usr/bin/env bash
#
# Bootstraps a Lima instance for building kernel modules.
#
# Arguments:
#   URL of a Fedora QEMU image (e.g. "https://mirror.example.com/fedora/linux/releases/37/Cloud/x86_64/images/fedora.qcow2")
#   SHA256 checksum of the Fedora QEMU image
#   Kernel version in the format <major>.<minor> (e.g. "5.19")
#   Absolute path to workspace

set -eu -o pipefail

source "${BASH_SOURCE[0]%/*}/lib/host/lima.sh"
source "${BASH_SOURCE[0]%/*}/lib/host/kernel.sh"
source "${BASH_SOURCE[0]%/*}/lib/host/util.sh"

declare img_url="${1?missing "'img_url'" positional parameter}"
declare img_sha="${2?missing "'img_sha'" positional parameter}"
declare kernel="${3?missing "'kernel'" positional parameter}"
declare workspace="${4?missing "'workspace'" positional parameter}"

declare arch
arch="$(util::linux_arch)"

declare scripts_base="${BASH_SOURCE[0]%/*}"
if [[ "${scripts_base::1}" != / ]]; then
	scripts_base="$(cd "${BASH_SOURCE[0]%/*}" && pwd -P)"
fi

>&2 echo '::debug::Generating Lima instance config with following parameters:'
>&2 echo "::debug::  Image URL: ${img_url}"
>&2 echo "::debug::  Image checksum: ${img_sha}"
>&2 echo "::debug::  Architecture: ${arch}"
>&2 echo "::debug::  Kernel: ${kernel}"
>&2 echo "::debug::  Workspace: ${workspace}"
>&2 echo "::debug::  Scripts base: ${scripts_base}"
lima::config::generate "$img_url" "$img_sha" "$arch" "$kernel" "$workspace" "$scripts_base"

>&2 echo '::debug::Refreshing Lima image cache'
lima::cache::refresh "$img_url" "$img_sha"

lima::vm::bootstrap

declare kernel_current kernel_installed
kernel_current="$(kernel::current)"
>&2 echo "::debug::Current running kernel is '${kernel_current}'"
kernel_installed="$(kernel::installed)"
>&2 echo "::debug::Latest installed kernel is '${kernel_installed}'"

if [[ "${kernel_current}" != "${kernel_installed}" ]]; then
	lima::vm::restart
fi
