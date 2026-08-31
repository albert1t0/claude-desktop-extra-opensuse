#!/usr/bin/env bash
set -euo pipefail

log() {
    printf '[claude-desktop-extra-opensuse] %s\n' "$*" >&2
}

die() {
    printf '[claude-desktop-extra-opensuse] ERROR: %s\n' "$*" >&2
    exit 1
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

rpm_version() {
    rpm -qp --qf '%{VERSION}' "$1"
}

rpm_arch() {
    rpm -qp --qf '%{ARCH}' "$1"
}

version_from_tarball_name() {
    local name
    name=$(basename "$1")
    if [[ "$name" =~ ^claude-desktop-([0-9]+\.[0-9]+\.[0-9]+)-linux(-aarch64)?\.tar\.gz$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

arch_from_tarball_name() {
    local name
    name=$(basename "$1")
    if [[ "$name" == *-linux-aarch64.tar.gz ]]; then
        printf 'aarch64\n'
    elif [[ "$name" == *-linux.tar.gz ]]; then
        printf 'x86_64\n'
    else
        return 1
    fi
}
