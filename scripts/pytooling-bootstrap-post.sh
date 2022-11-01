#!/usr/bin/env bash
#
# Wraps the 'bootstrap' step post command to make it executable by the
# pyTooling/Actions/with-post-step Action.

set -eu -o pipefail

echo '::group::Terminate Lima instance'
source "${BASH_SOURCE[0]%/*}"/lib/host/lima.sh
lima::vm::destroy "$STATE_LIMA_INSTANCE"
echo '::endgroup::'
