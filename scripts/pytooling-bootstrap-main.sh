#!/usr/bin/env bash
#
# Wraps the 'bootstrap' step main command to make it executable by the
# pyTooling/Actions/with-post-step Action.

set -eu -o pipefail

echo '::group::Bootstrap Lima instance'
# Since v0.4.4, with-post-step does not append a newline character after POST=true.
# https://github.com/pyTooling/Actions/commit/97fd0e59278300263d86ce71e1d45f295bf76cec
echo >>"$GITHUB_STATE"
echo "LIMA_INSTANCE=${LIMA_INSTANCE}" >>"$GITHUB_STATE"
"${BASH_SOURCE[0]%/*}"/bootstrap_builder.sh "$1" "$2" "$3" "$4"
echo '::endgroup::'
