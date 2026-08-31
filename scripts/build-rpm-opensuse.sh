#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat >&2 <<'USAGE'
Usage: build-rpm-opensuse.sh [--arch x86_64|aarch64] <tarball> <output-dir> [release]

Build an openSUSE RPM from an upstream Claude Desktop tarball.
The tarball name must be claude-desktop-VERSION-linux[-aarch64].tar.gz.
USAGE
}

ARCH=x86_64
if [[ "${1:-}" == "--arch" ]]; then
    [[ $# -ge 2 ]] || { usage; exit 2; }
    ARCH=$2
    shift 2
fi
case "$ARCH" in
    x86_64|aarch64) ;;
    *) die "unsupported architecture: $ARCH" ;;
esac

[[ $# -ge 2 && $# -le 3 ]] || { usage; exit 2; }
TARBALL=$1
OUTPUT_DIR=$2
PKGREL=${3:-opensuse1}

[[ -f "$TARBALL" ]] || die "tarball not found: $TARBALL"
need_command rpmbuild
need_command tar
VERSION=$(version_from_tarball_name "$TARBALL") ||
    die "unsupported tarball name: $(basename "$TARBALL")"
TARBALL_ARCH=$(arch_from_tarball_name "$TARBALL") ||
    die "cannot determine tarball architecture"
[[ "$TARBALL_ARCH" == "$ARCH" ]] ||
    die "tarball architecture is $TARBALL_ARCH, requested $ARCH"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
TOPDIR=$WORK_DIR/rpmbuild
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp -- "$TARBALL" "$TOPDIR/SOURCES/$(basename "$TARBALL")"
cp -- "$PROJECT_DIR/packaging/claude-desktop-extra-opensuse.spec" \
    "$TOPDIR/SPECS/"
mkdir -p "$OUTPUT_DIR"

log "building Claude Desktop $VERSION for $ARCH"
rpmbuild -bb \
    --target "$ARCH" \
    --define "_topdir $TOPDIR" \
    --define "pkg_version $VERSION" \
    --define "pkg_release $PKGREL" \
    --define "pkg_source $(basename "$TARBALL")" \
    "$TOPDIR/SPECS/claude-desktop-extra-opensuse.spec"

RPM_FILE=$(find "$TOPDIR/RPMS" -type f -name '*.rpm' -print -quit)
[[ -n "$RPM_FILE" ]] || die "rpmbuild produced no RPM"
DEST="$OUTPUT_DIR/$(basename "$RPM_FILE")"
cp -- "$RPM_FILE" "$DEST"
SHA256=$(sha256sum "$DEST" | awk '{print $1}')
cat > "$OUTPUT_DIR/rpm-info.txt" <<EOF
VERSION=$VERSION
ARCH=$ARCH
RELEASE=$PKGREL
RPM=$DEST
SHA256=$SHA256
EOF
log "built $DEST"
log "sha256: $SHA256"
