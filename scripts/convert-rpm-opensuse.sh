#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat >&2 <<'USAGE'
Usage: convert-rpm-opensuse.sh [--sha256 HASH] <fedora-rpm> <output-dir> [release]

Extract an existing Claude Desktop Extra RPM and repackage its payload with
openSUSE dependency names. The input payload is not modified.
USAGE
}

EXPECTED_SHA256=
if [[ "${1:-}" == "--sha256" ]]; then
    [[ $# -ge 2 ]] || { usage; exit 2; }
    EXPECTED_SHA256=$2
    shift 2
fi
[[ $# -ge 2 && $# -le 3 ]] || { usage; exit 2; }
INPUT_RPM=$1
OUTPUT_DIR=$2
PKGREL=${3:-opensuse1}

[[ -f "$INPUT_RPM" ]] || die "RPM not found: $INPUT_RPM"
need_command rpm
need_command rpm2cpio
need_command cpio
need_command rpmbuild
need_command tar
need_command sha256sum
need_command realpath
INPUT_RPM=$(realpath -- "$INPUT_RPM")

ARCH=$(rpm_arch "$INPUT_RPM")
case "$ARCH" in
    x86_64|aarch64) ;;
    *) die "unsupported input architecture: $ARCH" ;;
esac
VERSION=$(rpm_version "$INPUT_RPM")
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    die "cannot derive a semantic version from RPM: $VERSION"

if [[ -n "$EXPECTED_SHA256" ]]; then
    ACTUAL_SHA256=$(sha256sum "$INPUT_RPM" | awk '{print $1}')
    [[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] ||
        die "input SHA-256 mismatch (expected $EXPECTED_SHA256, got $ACTUAL_SHA256)"
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
PAYLOAD=$WORK_DIR/payload
mkdir -p "$PAYLOAD"
log "extracting $INPUT_RPM"
(cd "$PAYLOAD" && rpm2cpio "$INPUT_RPM" | cpio -idm --quiet)
[[ -d "$PAYLOAD/usr/lib/claude-desktop" ]] ||
    die "input RPM does not contain /usr/lib/claude-desktop"
[[ -x "$PAYLOAD/usr/bin/claude-desktop" ]] ||
    die "input RPM does not contain executable /usr/bin/claude-desktop"

tar -C "$PAYLOAD" -czf "$WORK_DIR/payload.tar.gz" .
(cd "$PAYLOAD" && find . -mindepth 1 -printf '/%P\n' | sort) \
    > "$WORK_DIR/filelist"

TOPDIR=$WORK_DIR/rpmbuild
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp -- "$WORK_DIR/payload.tar.gz" "$TOPDIR/SOURCES/payload.tar.gz"
cp -- "$WORK_DIR/filelist" "$TOPDIR/SOURCES/filelist"
cp -- "$PROJECT_DIR/packaging/repack-rpm.spec" "$TOPDIR/SPECS/"
mkdir -p "$OUTPUT_DIR"

log "building openSUSE RPM $VERSION for $ARCH"
rpmbuild -bb \
    --target "$ARCH" \
    --define "_topdir $TOPDIR" \
    --define "pkg_version $VERSION" \
    --define "pkg_release $PKGREL" \
    --define "pkg_source payload.tar.gz" \
    --define "pkg_filelist filelist" \
    "$TOPDIR/SPECS/repack-rpm.spec"

RPM_FILE=$(find "$TOPDIR/RPMS" -type f -name '*.rpm' -print -quit)
[[ -n "$RPM_FILE" ]] || die "rpmbuild produced no RPM"
DEST="$OUTPUT_DIR/$(basename "$RPM_FILE")"
cp -- "$RPM_FILE" "$DEST"
SHA256=$(sha256sum "$DEST" | awk '{print $1}')
cat > "$OUTPUT_DIR/rpm-info.txt" <<EOF
SOURCE_RPM=$INPUT_RPM
VERSION=$VERSION
ARCH=$ARCH
RELEASE=$PKGREL
RPM=$DEST
SHA256=$SHA256
EOF
log "built $DEST"
log "sha256: $SHA256"
