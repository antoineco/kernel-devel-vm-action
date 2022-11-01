#!/usr/bin/env bash
#
# Wraps the 'bootstrap' step main command to make it executable by the
# pyTooling/Actions/with-post-step Action.

set -eu -o pipefail

echo '::group::Bootstrap Lima instance'
echo "LIMA_INSTANCE=${LIMA_INSTANCE}" >>"$GITHUB_STATE"
"${BASH_SOURCE[0]%/*}"/bootstrap_builder.sh "$1" "$2" "$3" "$4"
echo '::endgroup::'
