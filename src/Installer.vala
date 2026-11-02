namespace AppRoller {
    public errordomain AppRollerError {
        FAILED
    }

    private class IconData : GLib.Object {
        public uint8[] bytes = {};
        public string extension = "";
        public uint64 score = 0;
    }

    public class Installer : GLib.Object {

        public static bool looks_like_appimage (string path) {
            if (!FileUtils.test (path, FileTest.IS_REGULAR)) {
                return false;
            }
            if (path.down ().has_suffix (".appimage")) {
                return true;
            }
            try {
                uint8[] data;
                FileUtils.get_data (path, out data);
                return data.length >= 10 && data[0] == 0x7f && data[1] == 'E' &&
                       data[2] == 'L' && data[3] == 'F' && data[8] == 'A' && data[9] == 'I';
            } catch (FileError e) {
                return false;
            }
        }

        public static AppImage inspect (string source) throws AppRollerError {
            try {
                var app = new AppImage ();
                app.source = Filename.canonicalize (source);
                if (!FileUtils.test (app.source, FileTest.IS_REGULAR)) {
                    throw new AppRollerError.FAILED ("That is not a file.");
                }
                if (!looks_like_appimage (app.source)) {
                    throw new AppRollerError.FAILED ("This file isnt a supported app. Choose a self contained application file.");
                }

                var stat = File.new_for_path (app.source).query_info ("standard::size", FileQueryInfoFlags.NONE);
                app.size = stat.get_size ();

                var scratch = new TempDir ();
                app.scratch = scratch;
                var extract_root = Path.build_filename (scratch.path, "extract");
                DirUtils.create (extract_root, 0755);

                var runnable = app.source;
                if (!FileUtils.test (app.source, FileTest.IS_EXECUTABLE)) {
                    runnable = Path.build_filename (scratch.path, "inspect.app");
                    uint8[] data;
                    FileUtils.get_data (app.source, out data);
                    FileUtils.set_data (runnable, data);
                    FileUtils.chmod (runnable, 0755);
                }

                run_extract (runnable, extract_root);
                var root = Path.build_filename (extract_root, "squashfs-root");
                if (!FileUtils.test (root, FileTest.IS_DIR)) {
                    throw new AppRollerError.FAILED ("The app did not contain a readable application image.");
                }
                root = Filename.canonicalize (root);

                var desktop_path = find_desktop_entry (root);
                var parsed = ParsedEntry ();
                var desktop_stem = "";
                if (desktop_path != null) {
                    string contents;
                    FileUtils.get_contents (desktop_path, out contents);
                    parsed = DesktopEntry.parse (contents);
                    desktop_stem = Path.get_basename (desktop_path);
                    if (desktop_stem.has_suffix (".desktop")) {
                        desktop_stem = desktop_stem.substring (0, desktop_stem.length - 8);
                    }
                }

                app.name = parsed.name != null ? parsed.name.strip () : "";
                if (app.name == "") {
                    app.name = display_name_from_path (app.source);
                }
                app.comment = parsed.comment;
                app.version = parsed.version;
                app.categories = parsed.categories;
                app.mime_types = parsed.mime_types;
                app.keywords = parsed.keywords;
                app.startup_wm_class = parsed.startup_wm_class;
                app.startup_notify = parsed.startup_notify;
                app.field_code = parsed.exec != null ? DesktopEntry.field_code (parsed.exec) : null;
                app.slug = slugify (desktop_stem != "" ? desktop_stem : app.name);

                var icon = extract_icon (root, parsed, app.slug);
                if (icon != null) {
                    app.icon_bytes = icon.bytes;
                    app.icon_extension = icon.extension;
                    app.preview_path = Path.build_filename (scratch.path, "icon." + icon.extension);
                    FileUtils.set_data (app.preview_path, icon.bytes);
                }
                return app;
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }

        private static void run_extract (string appimage, string working_directory) throws AppRollerError {
            try {
                var launcher = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
                launcher.set_cwd (working_directory);
                var process = launcher.spawnv ({ appimage, "--appimage-extract" });
                var timeout = Timeout.add_seconds (120, () => {
                    process.force_exit ();
                    return false;
                });
                process.wait_check ();
                Source.remove (timeout);
            } catch (Error e) {
                throw new AppRollerError.FAILED ("Could not unpack the app. If the app file is on a noexec filesystem move it somewhere else first. " + e.message);
            }
        }

        private static string? find_desktop_entry (string root) {
            string[] directories = { root, Path.build_filename (root, "usr/share/applications") };
            foreach (var directory in directories) {
                try {
                    var dir = Dir.open (directory);
                    string? name;
                    while ((name = dir.read_name ()) != null) {
                        if (name.has_suffix (".desktop")) {
                            return Path.build_filename (directory, name);
                        }
                    }
                } catch (FileError e) {
                }
            }
            return null;
        }

        private static IconData? extract_icon (string root, ParsedEntry parsed, string fallback) {
            IconData? best = read_icon (root, Path.build_filename (root, ".DirIcon"));
            var icon_name = DesktopEntry.first_icon_name (parsed.icon);
            string[] stems = { fallback };
            if (icon_name != null && icon_name != fallback) {
                stems += icon_name;
            }
            string[] directories = { Path.build_filename (root, "usr/share/icons"),
                                     Path.build_filename (root, "usr/share/pixmaps") };
            foreach (var directory in directories) {
                var found = collect_icons (root, directory, stems, 0);
                if (found != null && (best == null || found.score > best.score)) {
                    best = found;
                }
            }
            return best;
        }

        private static IconData? collect_icons (string root, string directory, string[] stems, int depth) {
            if (depth > 5) {
                return null;
            }
            IconData? best = null;
            try {
                var dir = Dir.open (directory);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    var path = Path.build_filename (directory, name);
                    if (FileUtils.test (path, FileTest.IS_DIR)) {
                        var found = collect_icons (root, path, stems, depth + 1);
                        if (found != null && (best == null || found.score > best.score)) {
                            best = found;
                        }
                    } else {
                        var stem = Path.get_basename (path).split (".")[0];
                        bool matches = false;
                        foreach (var wanted in stems) {
                            if (wanted.down () == stem.down ()) {
                                matches = true;
                                break;
                            }
                        }
                        if (!matches) {
                            continue;
                        }
                        var icon = read_icon (root, path);
                        if (icon != null && (best == null || icon.score > best.score)) {
                            best = icon;
                        }
                    }
                }
            } catch (FileError e) {
            }
            return best;
        }

        private static IconData? read_icon (string root, string path) {
            var safe = resolve_inside (root, path);
            if (safe == null || !FileUtils.test (safe, FileTest.IS_REGULAR)) {
                return null;
            }
            try {
                uint8[] data;
                FileUtils.get_data (safe, out data);
                if (data.length == 0 || data.length > 8 * 1024 * 1024) {
                    return null;
                }
                var extension = icon_extension (safe);
                if (extension == null) {
                    return null;
                }
                var icon = new IconData ();
                icon.bytes = data;
                icon.extension = extension;
                icon.score = icon_score (safe, extension);
                return icon;
            } catch (FileError e) {
                return null;
            }
        }

        private static string? resolve_inside (string root, string path) {
            var current = path;
            for (int i = 0; i < 16; i++) {
                if (FileUtils.test (current, FileTest.IS_SYMLINK)) {
                    try {
                        var target = FileUtils.read_link (current);
                        current = Path.is_absolute (target)
                            ? Path.build_filename (root, target.substring (1))
                            : Path.build_filename (Path.get_dirname (current), target);
                        current = Filename.canonicalize (current);
                        if (!current.has_prefix (root + "/")) {
                            return null;
                        }
                    } catch (FileError e) {
                        return null;
                    }
                } else {
                    var canonical = Filename.canonicalize (current);
                    if (!canonical.has_prefix (root + "/")) {
                        return null;
                    }
                    return canonical;
                }
            }
            return null;
        }

        private static string? icon_extension (string path) {
            int width;
            int height;
            var format = Gdk.Pixbuf.get_file_info (path, out width, out height);
            if (format != null) {
                var name = format.get_name ();
                if (name == "png" || name == "svg" || name == "jpeg" || name == "jpg" || name == "xpm") {
                    return name == "jpeg" ? "jpg" : name;
                }
            }
            var lower = path.down ();
            string[] extensions = { "png", "svg", "jpg", "jpeg", "xpm" };
            foreach (var extension in extensions) {
                if (lower.has_suffix ("." + extension)) {
                    return extension == "jpeg" ? "jpg" : extension;
                }
            }
            try {
                uint8[] data;
                FileUtils.get_data (path, out data);
                var head = ((string) data).substring (0, int.min (data.length, 4096)).down ();
                if (head.contains ("<svg")) {
                    return "svg";
                }
                if (head.has_prefix ("/* xpm */")) {
                    return "xpm";
                }
            } catch (FileError e) {
            }
            return null;
        }

        private static uint64 icon_score (string path, string extension) {
            if (extension == "svg") {
                return 1000000000;
            }
            int width;
            int height;
            Gdk.Pixbuf.get_file_info (path, out width, out height);
            return (uint64) width * (uint64) height + 500;
        }

        public static string target_path (AppImage app) {
            return Path.build_filename (System.applications_dir (), sanitize_file_stem (app.name) + ".AppImage");
        }

        public static Installed install (AppImage app) throws AppRollerError {
            try {
                DirUtils.create_with_parents (System.applications_dir (), 0755);
                var target = target_path (app);
                if (app.source != target) {
                    uint8[] data;
                    FileUtils.get_data (app.source, out data);
                    var temporary = target + ".tmp-" + ((int) Posix.getpid ()).to_string ();
                    FileUtils.set_data (temporary, data);
                    FileUtils.chmod (temporary, 0755);
                    if (FileUtils.rename (temporary, target) != 0) {
                        throw new AppRollerError.FAILED ("Could not replace the installed app.");
                    }
                } else {
                    FileUtils.chmod (target, 0755);
                }

                string? icon_path = null;
                if (app.icon_bytes != null && app.icon_extension != null) {
                    icon_path = write_icon (app.slug, app.icon_bytes, app.icon_extension);
                }
                var desktop_path = install_desktop_entry (app, target, icon_path);
                System.update_desktop_database ();
                var result = new Installed ();
                result.name = app.name;
                result.app_path = target;
                result.desktop_path = desktop_path;
                result.icon_path = icon_path;
                return result;
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }

        private static string install_desktop_entry (AppImage app, string app_path, string? icon_path) throws Error {
            var keyfile = new KeyFile ();
            keyfile.set_string (DesktopEntry.GROUP, "Type", "Application");
            keyfile.set_string (DesktopEntry.GROUP, "Name", app.name);
            if (app.comment != null) {
                keyfile.set_string (DesktopEntry.GROUP, "Comment", app.comment);
            }
            var exec = DesktopEntry.quote_exec (app_path);
            if (app.field_code != null) {
                exec += " " + app.field_code;
            }
            keyfile.set_string (DesktopEntry.GROUP, "Exec", exec);
            keyfile.set_string (DesktopEntry.GROUP, "TryExec", DesktopEntry.quote_exec (app_path));
            keyfile.set_string (DesktopEntry.GROUP, "Icon", icon_path != null ? icon_path : "application-x-executable");
            keyfile.set_boolean (DesktopEntry.GROUP, "Terminal", false);
            keyfile.set_boolean (DesktopEntry.GROUP, "StartupNotify", app.startup_notify);
            keyfile.set_string (DesktopEntry.GROUP, "Categories", app.categories != null ? app.categories : "Utility;");
            if (app.mime_types != null) {
                keyfile.set_string (DesktopEntry.GROUP, "MimeType", app.mime_types);
            }
            if (app.keywords != null) {
                keyfile.set_string (DesktopEntry.GROUP, "Keywords", app.keywords);
            }
            if (app.startup_wm_class != null) {
                keyfile.set_string (DesktopEntry.GROUP, "StartupWMClass", app.startup_wm_class);
            }
            keyfile.set_string (DesktopEntry.GROUP, "X-AppImage-Name", app.name);
            if (app.version != null) {
                keyfile.set_string (DesktopEntry.GROUP, "X-AppImage-Version", app.version);
            }
            keyfile.set_boolean (DesktopEntry.GROUP, "X-AppRoller-Managed", true);
            keyfile.set_string (DesktopEntry.GROUP, "X-AppRoller-App", app_path);

            var directory = System.desktop_dir ();
            DirUtils.create_with_parents (directory, 0755);
            var path = Path.build_filename (directory, app.slug + ".desktop");
            if (FileUtils.test (path, FileTest.EXISTS)) {
                string contents;
                FileUtils.get_contents (path, out contents);
                if (!DesktopEntry.is_managed (contents)) {
                    path = Path.build_filename (directory, app.slug + "-approller.desktop");
                }
            }
            var data = keyfile.to_data ();
            FileUtils.set_contents (path, data);
            return path;
        }

        public static string install_icon_file (string slug, string source) throws AppRollerError {
            try {
                uint8[] data;
                FileUtils.get_data (source, out data);
                var extension = icon_extension (source);
                if (extension == null) {
                    throw new AppRollerError.FAILED ("That file is not a png, svg, jpeg or xpm image.");
                }
                return write_icon (slug, data, extension);
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }

        private static string write_icon (string slug, uint8[] data, string extension) throws Error {
            var directory = System.icon_dir ();
            DirUtils.create_with_parents (directory, 0755);
            remove_icon_variants (directory, slug, null);
            var path = Path.build_filename (directory, slug + "." + extension);
            FileUtils.set_data (path, data);
            return path;
        }

        public static void remove_icon_files (string slug) {
            remove_icon_variants (System.icon_dir (), slug, null);
        }

        private static void remove_icon_variants (string directory, string slug, string? keep) {
            try {
                var dir = Dir.open (directory);
                string? name;
                while ((name = dir.read_name ()) != null) {
                    var path = Path.build_filename (directory, name);
                    if (keep != null && path == keep) {
                        continue;
                    }
                    var parts = Path.get_basename (path).split (".");
                    if (parts.length < 2 || parts[0] != slug) {
                        continue;
                    }
                    var extension = parts[1].down ();
                    if (extension == "png" || extension == "svg" || extension == "jpg" ||
                        extension == "jpeg" || extension == "xpm") {
                        FileUtils.remove (path);
                    }
                }
            } catch (FileError e) {
            }
        }

        private static string display_name_from_path (string path) {
            var stem = Path.get_basename (path);
            var dot = stem.last_index_of (".");
            if (dot > 0) {
                stem = stem.substring (0, dot);
            }
            var cleaned = stem.replace ("-", " ").replace ("_", " ").strip ();
            if (cleaned == "") {
                return "App";
            }
            if (cleaned.down () == cleaned) {
                var words = cleaned.split (" ");
                for (int i = 0; i < words.length; i++) {
                    if (words[i].length > 0) {
                        words[i] = words[i].substring (0, 1).up () + words[i].substring (1);
                    }
                }
                return string.joinv (" ", words);
            }
            return cleaned;
        }

        private static string slugify (string name) {
            var slug = name.down ().replace (" ", "-");
            var result = new StringBuilder ();
            for (int i = 0; i < slug.length; i++) {
                var c = slug[i];
                if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) {
                    result.append_c (c);
                } else if (result.len > 0 && result.str[result.len - 1] != '-') {
                    result.append_c ('-');
                }
            }
            var value = result.str;
            while (value.has_prefix ("-")) {
                value = value.substring (1);
            }
            while (value.has_suffix ("-")) {
                value = value.substring (0, value.length - 1);
            }
            if (value == "") {
                value = "app";
            }
            return value.substring (0, value.length > 48 ? 48 : value.length);
        }

        private static string sanitize_file_stem (string name) {
            var stem = name.strip ();
            if (stem.down ().has_suffix (".appimage")) {
                stem = stem.substring (0, stem.length - 9);
            }
            var result = "";
            for (int i = 0; i < stem.length; i++) {
                var c = stem[i];
                if (c == '/' || c == '\\' || c == ':' || c == '\0' || c < ' ') {
                    result += "-";
                } else {
                    result += c.to_string ();
                }
            }
            result = result.strip ();
            while (result.has_prefix (".")) {
                result = result.substring (1);
            }
            while (result.has_suffix (".")) {
                result = result.substring (0, result.length - 1);
            }
            if (result == "" || result == "." || result == "..") {
                return "App";
            }
            return result.substring (0, result.length > 80 ? 80 : result.length);
        }
    }
}
