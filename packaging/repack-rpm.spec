%define _build_id_links none
%global debug_package %{nil}

# The Electron tree contains bundled ELF files which must not create host
# dependency/provides entries. Dependencies for the openSUSE host are listed
# explicitly below.
%global __requires_exclude_from ^/usr/lib/claude-desktop/.*$
%global __provides_exclude_from ^/usr/lib/claude-desktop/.*$

Name: claude-desktop-extra
Version: %{pkg_version}
Release: %{?pkg_release}%{!?pkg_release:opensuse1}
Summary: Claude Desktop for Linux with extra features
License: Proprietary
URL: https://claude.ai
Source0: %{pkg_source}
Source1: %{pkg_filelist}

ExclusiveArch: x86_64 aarch64

# Fedora/RHEL names translated to openSUSE package names.
Requires: gtk3
Requires: mozilla-nss
Requires: libXss1
Requires: libXtst6
Requires: at-spi2-core
Requires: libdrm2
Requires: libgbm1
Requires: alsa-lib
Requires: libnotify4
Requires: libsecret-1-0
Requires: xdg-utils
Requires: xdg-desktop-portal

Obsoletes: claude-desktop-bin <= 1.24012.9
Provides: claude-desktop-bin = %{version}-%{release}

%description
Anthropic's official Claude Desktop for Linux, repackaged for openSUSE with
Linux-only features such as Computer Use, themes, multiple profiles, and
Quick Entry.

This package is an unofficial community build and requires an Anthropic
account.

%prep
mkdir -p payload
tar -xzf %{SOURCE0} -C payload

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a payload/. %{buildroot}/

%post
if [ -f /usr/lib/claude-desktop/chrome-sandbox ]; then
    chown root:root /usr/lib/claude-desktop/chrome-sandbox
    chmod 4755 /usr/lib/claude-desktop/chrome-sandbox
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || :
fi

%postun
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database /usr/share/applications >/dev/null 2>&1 || :
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || :
fi

%files -f %{SOURCE1}
