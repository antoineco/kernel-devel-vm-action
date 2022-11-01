#!/usr/bin/env bash
#
# Installs the selected kernel version.
#
# Arguments:
#   Kernel version in the format <major>.<minor> (e.g. "5.19")

set -eu -o pipefail

source "${BASH_SOURCE[0]%/*}/lib/builder/kernel.sh"

declare kernel="${1?missing "'kernel'" positional parameter}"

export HOME="${HOME:-/root}"

declare buildid
buildid="$(kernel::build::lookup "$kernel")"

declare kernel_current kernel_desired
kernel_current="$(kernel::current)"
kernel_desired="$(kernel::from_buildid "$buildid")"

if [[ "${kernel_current}" != "${kernel_desired}" ]] || ! os::is_installed "kernel-devel-${kernel_desired}"; then
	kernel::build::install "$buildid"
fi

if [[ "${kernel_current}" != "${kernel_desired}" ]]; then
	os::bootloader::set_default "$kernel_desired"
fi
