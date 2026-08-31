#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../scripts/common.sh
source "$ROOT/scripts/common.sh"

pass() {
    printf 'ok - %s\n' "$1"
}

expect_failure() {
    local description=$1
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'not ok - %s (unexpected success)\n' "$description" >&2
        exit 1
    fi
    pass "$description"
}

[[ "$(version_from_tarball_name claude-desktop-1.40609.0-linux.tar.gz)" == "1.40609.0" ]]
pass "extract x86_64 tarball version"
[[ "$(version_from_tarball_name claude-desktop-1.40609.0-linux-aarch64.tar.gz)" == "1.40609.0" ]]
pass "extract aarch64 tarball version"
[[ "$(arch_from_tarball_name claude-desktop-1.40609.0-linux.tar.gz)" == "x86_64" ]]
pass "detect x86_64 tarball architecture"
[[ "$(arch_from_tarball_name claude-desktop-1.40609.0-linux-aarch64.tar.gz)" == "aarch64" ]]
pass "detect aarch64 tarball architecture"

expect_failure "reject malformed tarball name" \
    version_from_tarball_name claude-desktop-invalid.tar.gz
expect_failure "reject invalid converter arguments" \
    "$ROOT/scripts/convert-rpm-opensuse.sh"
expect_failure "reject invalid native builder arguments" \
    "$ROOT/scripts/build-rpm-opensuse.sh"

grep -Fxq 'Requires: libdrm2' "$ROOT/packaging/claude-desktop-extra-opensuse.spec"
grep -Fxq 'Requires: libgbm1' "$ROOT/packaging/claude-desktop-extra-opensuse.spec"
if grep -Eq '^Requires: (mesa-libgbm|libdrm)$' \
    "$ROOT/packaging/claude-desktop-extra-opensuse.spec"; then
    printf 'not ok - Fedora dependency leaked into native spec\n' >&2
    exit 1
fi
pass "native spec uses openSUSE dependency names"

printf 'all tests passed\n'
