%define _build_id_links none
%global debug_package %{nil}

# Do not harvest dependencies/provides from bundled Electron and bridge
# binaries. The host dependencies below are the openSUSE package names.
%global __requires_exclude_from ^/usr/lib/claude-desktop/.*$
%global __provides_exclude_from ^/usr/lib/claude-desktop/.*$

Name: claude-desktop-extra
Version: %{pkg_version}
Release: %{?pkg_release}%{!?pkg_release:opensuse1}
Summary: Claude Desktop for Linux with extra features
License: Proprietary
URL: https://claude.ai
Source0: %{pkg_source}

ExclusiveArch: x86_64 aarch64

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
mkdir -p tarball
tar -xzf %{SOURCE0} -C tarball
test -d tarball/claude-desktop
test -f tarball/launcher/claude-desktop

%install
rm -rf %{buildroot}

mkdir -p %{buildroot}/usr/lib/claude-desktop
cp -a tarball/claude-desktop/. %{buildroot}/usr/lib/claude-desktop/

install -Dm755 tarball/launcher/claude-desktop \
    %{buildroot}/usr/bin/claude-desktop

install -Dm644 tarball/copyright \
    %{buildroot}/usr/share/licenses/%{name}/copyright

install -d %{buildroot}/usr/share/applications
cat > %{buildroot}/usr/share/applications/com.anthropic.Claude.desktop <<'DESKTOP'
[Desktop Entry]
Name=Claude
Comment=Desktop application for Claude.ai
GenericName=AI Assistant
Keywords=AI;Chat;Assistant;Claude;Code;LLM;
Exec=claude-desktop %U
Icon=claude-desktop
Type=Application
StartupNotify=true
StartupWMClass=com.anthropic.Claude
SingleMainWindow=true
Categories=Utility;Development;
MimeType=x-scheme-handler/claude;
Actions=NewChat;NewCode;

[Desktop Action NewChat]
Name=New chat
Exec=claude-desktop claude://claude.ai/new

[Desktop Action NewCode]
Name=New Claude Code session
Exec=claude-desktop claude://code/new
DESKTOP

if [ -d tarball/icons/hicolor ]; then
    install -d %{buildroot}/usr/share/icons
    cp -a tarball/icons/hicolor %{buildroot}/usr/share/icons/
fi

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

%files
%{_bindir}/claude-desktop
/usr/lib/claude-desktop
%{_datadir}/applications/com.anthropic.Claude.desktop
%{_datadir}/licenses/%{name}/copyright
%{_datadir}/icons/hicolor
