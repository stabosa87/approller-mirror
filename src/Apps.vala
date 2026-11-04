namespace AppRoller {
    public class Apps : GLib.Object {
        public static GLib.List<InstalledApp> list () {
            var result = new GLib.List<InstalledApp> ();
            try {
                var dir = Dir.open (System.desktop_dir ());
                string? name;
                while ((name = dir.read_name ()) != null) {
                    if (!name.has_suffix (".desktop")) {
                        continue;
                    }
                    var path = Path.build_filename (System.desktop_dir (), name);
                    string contents;
                    try {
                        FileUtils.get_contents (path, out contents);
                    } catch (FileError e) {
                        continue;
                    }
                    if (!DesktopEntry.is_managed (contents)) {
                        continue;
                    }
                    var parsed = DesktopEntry.parse (contents);
                    var app_path = parsed.app_path != null ? parsed.app_path : parsed.try_exec;
                    var executable = app_path != null ? DesktopEntry.exec_path (app_path) : null;
                    if (executable == null) {
                        continue;
                    }
                    var app = new InstalledApp ();
                    app.name = parsed.name != null && parsed.name.strip () != "" ? parsed.name : Path.get_basename (name);
                    app.comment = parsed.comment;
                    app.version = parsed.version;
                    app.slug = Path.get_basename (name).split (".")[0];
                    app.categories = parsed.categories;
                    app.arguments = parsed.arguments;
                    app.field_code = parsed.exec != null ? DesktopEntry.field_code (parsed.exec) : null;
                    app.app_path = executable;
                    app.desktop_path = path;
                    app.icon = parsed.icon;
                    app.available = FileUtils.test (executable, FileTest.IS_REGULAR);
                    app.icon_path = resolve_icon (app.slug, parsed.icon);
                    result.append (app);
                }
            } catch (FileError e) {
            }
            result.sort ((a, b) => a.name.down ().collate (b.name.down ()));
            return result;
        }

        public static string? installed_version (string app_path) {
            foreach (var app in list ()) {
                if (app.app_path == app_path) {
                    return app.version;
                }
            }
            return null;
        }

        private static string? resolve_icon (string slug, string? icon) {
            if (icon == null) {
                return null;
            }
            if (Path.is_absolute (icon)) {
                return FileUtils.test (icon, FileTest.IS_REGULAR) ? icon : null;
            }
            if (icon == "application-x-executable") {
                return null;
            }
            var stem = DesktopEntry.first_icon_name (icon);
            string[] extensions = { "svg", "png", "jpg", "jpeg", "xpm" };
            foreach (var extension in extensions) {
                var path = Path.build_filename (System.icon_dir (), slug + "." + extension);
                if (FileUtils.test (path, FileTest.IS_REGULAR)) {
                    return path;
                }
                if (stem != null && stem != slug) {
                    path = Path.build_filename (System.icon_dir (), stem + "." + extension);
                    if (FileUtils.test (path, FileTest.IS_REGULAR)) {
                        return path;
                    }
                }
            }
            return null;
        }

        public static void save_config (InstalledApp app, Config config) throws AppRollerError {
            if (config.name.strip () == "") {
                throw new AppRollerError.FAILED ("The app name cannot be empty.");
            }
            try {
                string contents;
                FileUtils.get_contents (app.desktop_path, out contents);
                var keyfile = new KeyFile ();
                keyfile.load_from_data (contents, contents.length, KeyFileFlags.NONE);
                keyfile.set_string (DesktopEntry.GROUP, "Name", config.name.strip ());
                if (config.comment.strip () == "") {
                    remove_key (keyfile, "Comment");
                } else {
                    keyfile.set_string (DesktopEntry.GROUP, "Comment", config.comment.strip ());
                }
                keyfile.set_string (DesktopEntry.GROUP, "Categories", config.categories);
                var exec = DesktopEntry.quote_exec (app.app_path);
                if (config.arguments.strip () != "") {
                    exec += " " + config.arguments.strip ();
                    keyfile.set_string (DesktopEntry.GROUP, "X-AppRoller-Args", config.arguments.strip ());
                } else {
                    remove_key (keyfile, "X-AppRoller-Args");
                }
                if (app.field_code != null) {
                    exec += " " + app.field_code;
                }
                keyfile.set_string (DesktopEntry.GROUP, "Exec", exec);
                keyfile.set_string (DesktopEntry.GROUP, "X-AppRoller-App", app.app_path);
                if (config.icon_source != null) {
                    var icon = Installer.install_icon_file (app.slug, config.icon_source);
                    keyfile.set_string (DesktopEntry.GROUP, "Icon", icon);
                }
                FileUtils.set_contents (app.desktop_path, keyfile.to_data ());
                System.update_desktop_database ();
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }

        private static void remove_key (KeyFile keyfile, string key) {
            try {
                keyfile.remove_key (DesktopEntry.GROUP, key);
            } catch (KeyFileError e) {
            }
        }

        public static void remove (InstalledApp app) throws AppRollerError {
            try {
                string contents;
                FileUtils.get_contents (app.desktop_path, out contents);
                if (!DesktopEntry.is_managed (contents)) {
                    throw new AppRollerError.FAILED ("That desktop entry is not managed by Approller.");
                }
                var applications = Filename.canonicalize (System.applications_dir ());
                var app_path = Filename.canonicalize (app.app_path);
                if (!app_path.has_prefix (applications + "/")) {
                    throw new AppRollerError.FAILED ("Refusing to delete an app outside Applications.");
                }
                if (FileUtils.test (app_path, FileTest.EXISTS)) {
                    FileUtils.remove (app_path);
                }
                FileUtils.remove (app.desktop_path);
                Installer.remove_icon_files (app.slug);
                if (app.icon_path != null) {
                    var stem = Path.get_basename (app.icon_path).split (".")[0];
                    if (stem != app.slug) {
                        Installer.remove_icon_files (stem);
                    }
                }
                System.update_desktop_database ();
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }
    }
}
