Name:           approller
Version:        0.1.0
Release:        1%{?dist}
Summary:        Install and manage apps.
License:        MIT
URL:            https://git.stab.ing/stabosa87/AppRoller
Source0:        https://git.stab.ing/stabosa87/AppRoller/archive/master.zip

BuildRequires:  meson
BuildRequires:  ninja-build
BuildRequires:  vala
BuildRequires:  gcc
BuildRequires:  pkgconf-pkg-config
BuildRequires:  glib2-devel
BuildRequires:  gtk4-devel >= 4.10
BuildRequires:  libadwaita-devel >= 1.4
BuildRequires:  gdk-pixbuf2-devel
BuildRequires:  desktop-file-utils
BuildRequires:  unzip

Requires:       hicolor-icon-theme
Requires(post): desktop-file-utils
Requires(post): shared-mime-info
Requires(post): gtk-update-icon-cache
Requires(postun): desktop-file-utils
Requires(postun): shared-mime-info
Requires(postun): gtk-update-icon-cache

%description
An app image installer written in Vala.

To simplify installing app image's for newer users and (similar) ui to what users already know! With a beautiful* UI using libadwaita.
%prep
%autosetup -c -T
unzip -q %{SOURCE0}
mv approller/* .
mv approller/.[!.]* . 2>/dev/null || :
rmdir approller

%build
%meson
%meson_build

%install
%meson_install

%post
update-desktop-database %{_datadir}/applications >/dev/null 2>&1 || :
update-mime-database %{_datadir}/mime >/dev/null 2>&1 || :
gtk-update-icon-cache -q -t -f %{_datadir}/icons/hicolor >/dev/null 2>&1 || :

%postun
update-desktop-database %{_datadir}/applications >/dev/null 2>&1 || :
update-mime-database %{_datadir}/mime >/dev/null 2>&1 || :
gtk-update-icon-cache -q -t -f %{_datadir}/icons/hicolor >/dev/null 2>&1 || :

%files
%{_bindir}/approller
%{_datadir}/applications/ing.stab.AppRoller.desktop
%{_datadir}/icons/hicolor/scalable/apps/ing.stab.AppRoller.svg
%{_datadir}/mime/packages/ing.stab.AppRoller.xml
%doc README.md
%license LICENSE
