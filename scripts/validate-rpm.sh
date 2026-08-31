#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat >&2 <<'USAGE'
Usage: validate-rpm.sh <rpm>

Validate package metadata and the files needed to launch Claude Desktop.
This command does not install or modify the package.
USAGE
}

[[ $# -eq 1 ]] || { usage; exit 2; }
RPM_FILE=$1
[[ -f "$RPM_FILE" ]] || die "RPM not found: $RPM_FILE"
need_command rpm

NAME=$(rpm -qp --qf '%{NAME}' "$RPM_FILE")
VERSION=$(rpm -qp --qf '%{VERSION}-%{RELEASE}' "$RPM_FILE")
ARCH=$(rpm -qp --qf '%{ARCH}' "$RPM_FILE")
[[ "$NAME" == "claude-desktop-extra" ]] ||
    die "unexpected package name: $NAME"
case "$ARCH" in
    x86_64|aarch64) ;;
    *) die "unsupported package architecture: $ARCH" ;;
esac

REQUIRES=$(rpm -qpR "$RPM_FILE")
for forbidden in mesa-libgbm libdrm; do
    if grep -Fxq "$forbidden" <<<"$REQUIRES"; then
        die "Fedora dependency remains in package metadata: $forbidden"
    fi
done
for required in gtk3 mozilla-nss libXss1 libXtst6 at-spi2-core libdrm2 libgbm1 \
    alsa-lib libnotify4 libsecret-1-0 xdg-utils xdg-desktop-portal; do
    grep -Fxq "$required" <<<"$REQUIRES" ||
        die "openSUSE dependency missing from package metadata: $required"
done

FILES=$(rpm -qpl "$RPM_FILE")
for required_file in /usr/bin/claude-desktop \
    /usr/share/applications/com.anthropic.Claude.desktop \
    /usr/lib/claude-desktop; do
    grep -Fxq "$required_file" <<<"$FILES" ||
        die "required file missing: $required_file"
done

printf 'valid: %s-%s.%s\n' "$NAME" "$VERSION" "$ARCH"
printf 'sha256: '
sha256sum "$RPM_FILE" | awk '{print $1}'
