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
            string contents;
            FileUtils.get_contents (desktop_path, out contents);
            var parsed = DesktopEntry.parse (contents);
            if (parsed.exec == null) {
                throw new IOError.NOT_FOUND ("Could not read the desktop entry at %s.", desktop_path);
            }

            string[] argv;
            Shell.parse_argv (parsed.exec, out argv);
            var command = without_field_codes (argv);
            if (command.length == 0) {
                throw new IOError.NOT_FOUND ("Could not read the desktop entry at %s.", desktop_path);
            }

            spawn_orphan (command);
        }

        private static string[] without_field_codes (string[] argv) {
            string[] result = {};
            foreach (var arg in argv) {
                if (arg.length == 2 && arg[0] == '%') {
                    continue;
                }
                result += arg;
            }
            return result;
        }

        private static void spawn_orphan (string[] argv) throws Error {
            string[] prefix = {};
            if (is_flatpak ()) {
                prefix = { "flatpak-spawn", "--host", "--directory=" + home_dir () };
            } else {
                var setsid = Environment.find_program_in_path ("setsid");
                if (setsid != null) {
                    prefix = { setsid };
                }
            }

            var command = new string[prefix.length + argv.length];
            for (int i = 0; i < prefix.length; i++) {
                command[i] = prefix[i];
            }
            for (int i = 0; i < argv.length; i++) {
                command[prefix.length + i] = argv[i];
            }

            Pid pid;
            Process.spawn_async (home_dir (), command, null,
                                 SpawnFlags.SEARCH_PATH |
                                 SpawnFlags.STDOUT_TO_DEV_NULL |
                                 SpawnFlags.STDERR_TO_DEV_NULL,
                                 null, out pid);
        }
    }
}
