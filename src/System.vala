namespace AppRoller {
    public class System : GLib.Object {
        public static bool is_flatpak () {
            return Environment.get_variable ("FLATPAK_ID") != null;
        }

        public static string home_dir () {
            return Environment.get_home_dir ();
        }

        public static string data_home () {
            return Environment.get_user_data_dir ();
        }

        public static string applications_dir () {
            return Path.build_filename (home_dir (), "Applications");
        }

        public static string icon_dir () {
            return Path.build_filename (applications_dir (), ".icons");
        }

        public static string desktop_dir () {
            if (is_flatpak ()) {
                return Path.build_filename (home_dir (), ".local", "share", "applications");
            }
            return Path.build_filename (data_home (), "applications");
        }

        public static string pretty_path (string path) {
            var home = home_dir ();
            if (path == home) {
                return "~";
            }
            if (path.has_prefix (home + "/")) {
                return "~/" + path.substring (home.length + 1);
            }
            return path;
        }

        public static string human_size (uint64 size) {
            return GLib.format_size (size);
        }

        public static void update_desktop_database () {
            try {
                var process = new Subprocess (SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE,
                                              "update-desktop-database", desktop_dir ());
                process.wait ();
            } catch (Error e) {
            }
        }

        public static void open_directory (string directory) {
            try {
                AppInfo.launch_default_for_uri (File.new_for_path (directory).get_uri (), null);
            } catch (Error e) {
            }
        }

        public static void show_in_files (string path) {
            if (FileUtils.test (path, FileTest.IS_DIR)) {
                open_directory (path);
            } else {
                open_directory (Path.get_dirname (path));
            }
        }

        public static void launch_desktop_entry (string desktop_path) throws Error {
            var info = new DesktopAppInfo.from_filename (desktop_path);
            if (info == null) {
                throw new IOError.NOT_FOUND ("Could not read the desktop entry at %s.", desktop_path);
            }
            info.launch (null, null);
        }
    }
}
