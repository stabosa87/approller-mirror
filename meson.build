project('approller', 'vala', 'c', version: '0.1.1')

gnome = import('gnome')

dependencies = [
  dependency('glib-2.0'),
  dependency('gio-2.0'),
  dependency('gio-unix-2.0'),
  dependency('gdk-pixbuf-2.0'),
  dependency('gtk4', version: '>=4.10'),
  dependency('libadwaita-1', version: '>=1.4'),
]

resources = gnome.compile_resources(
  'approller-resources',
  'resources/approller.gresource.xml',
  source_dir: 'resources',
  c_name: 'app_roller',
)

sources = files(
  'src/AppImage.vala',
  'src/InstalledApp.vala',
  'src/DesktopEntry.vala',
  'src/System.vala',
  'src/Installer.vala',
  'src/Apps.vala',
  'src/Helpers.vala',
  'src/LibraryPage.vala',
  'src/ReadyPage.vala',
  'src/InstallingPage.vala',
  'src/DonePage.vala',
  'src/ErrorPage.vala',
  'src/ConfigDialog.vala',
  'src/Window.vala',
  'src/Application.vala',
)
sources += resources

executable('approller',
  sources,
  dependencies: dependencies,
  vala_args: ['--target-glib=2.76', '--pkg', 'posix'],
  install: true,
)

desktop_conf = configuration_data()
desktop_conf.set('EXEC', join_paths(get_option('prefix'), get_option('bindir'), 'approller'))
desktop_file = configure_file(
  input: 'data/ing.stab.AppRoller.desktop',
  output: 'ing.stab.AppRoller.desktop',
  configuration: desktop_conf,
)
install_data(desktop_file,
  install_dir: get_option('datadir') / 'applications')

install_data('data/ing.stab.AppRoller.xml',
  install_dir: get_option('datadir') / 'mime/packages')

install_data('data/icons/hicolor/scalable/apps/ing.stab.AppRoller.svg',
  install_dir: get_option('datadir') / 'icons/hicolor/scalable/apps')

install_data('data/ing.stab.AppRoller.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo')

install_data('LICENSE',
  install_dir: get_option('datadir') / 'licenses' / 'ing.stab.AppRoller')
