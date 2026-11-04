# Building AppRoller

## Dependencies

Fedora:

```sh
sudo dnf install meson ninja-build vala gcc pkgconf-pkg-config glib2-devel gtk4-devel libadwaita-devel gdk-pixbuf2-devel
```

Ubuntu 24.04 or newer:

```sh
sudo apt install meson ninja-build valac gcc pkg-config libglib2.0-dev libgtk-4-dev libadwaita-1-dev libgdk-pixbuf-2.0-dev
```

## Build

```sh
meson setup build
meson compile -C build
```

Run it:

```sh
./build/approller
```

Install it:

```sh
sudo meson install -C build
```