namespace AppRoller {
    public struct ParsedEntry {
        public string? name;
        public string? comment;
        public string? categories;
        public string? mime_types;
        public string? keywords;
        public string? startup_wm_class;
        public string? icon;
        public string? exec;
        public string? try_exec;
        public string? app_path;
        public string? arguments;
        public string? version;
        public bool startup_notify;
    }

    public class DesktopEntry {
        public const string GROUP = "Desktop Entry";

        public static ParsedEntry parse (string contents) {
            var entry = ParsedEntry ();
            var keyfile = new KeyFile ();
            try {
                keyfile.load_from_data (contents, contents.length, KeyFileFlags.NONE);
            } catch (KeyFileError e) {
                return entry;
            }

            entry.name = get (keyfile, "Name");
            entry.comment = get (keyfile, "Comment");
            entry.categories = get (keyfile, "Categories");
            entry.mime_types = get (keyfile, "MimeType");
            entry.keywords = get (keyfile, "Keywords");
            entry.startup_wm_class = get (keyfile, "StartupWMClass");
            entry.icon = get (keyfile, "Icon");
            entry.exec = get (keyfile, "Exec");
            entry.try_exec = get (keyfile, "TryExec");
            entry.app_path = get (keyfile, "X-AppRoller-App");
            entry.arguments = get (keyfile, "X-AppRoller-Args");
            entry.version = get (keyfile, "X-AppImage-Version");
            try {
                entry.startup_notify = keyfile.get_boolean (GROUP, "StartupNotify");
            } catch (KeyFileError e) {
                entry.startup_notify = false;
            }
            if (entry.name == null) {
                entry.name = get (keyfile, "X-AppImage-Name");
            }
            return entry;
        }

        private static string? get (KeyFile keyfile, string key) {
            try {
                return keyfile.get_string (GROUP, key);
            } catch (KeyFileError e) {
                return null;
            }
        }

        public static bool is_managed (string contents) {
            foreach (var line in contents.split ("\n")) {
                if (line.strip () == "X-AppRoller-Managed=true") {
                    return true;
                }
            }
            return false;
        }

        public static string? field_code (string exec) {
            if (exec.contains ("%F") || exec.contains ("%f")) {
                return "%F";
            }
            if (exec.contains ("%U") || exec.contains ("%u")) {
                return "%U";
            }
            return null;
        }

        public static string? exec_path (string exec) {
            try {
                string[] argv;
                Shell.parse_argv (exec, out argv);
                if (argv.length == 0) {
                    return null;
                }
                if (Path.is_absolute (argv[0])) {
                    return argv[0];
                }
                return Path.build_filename (Environment.get_home_dir (), argv[0]);
            } catch (ShellError e) {
                return null;
            }
        }

        public static string quote_exec (string path) {
            if (!path.contains (" ") && !path.contains ("\t") && !path.contains ("\n") &&
                !path.contains ("\"") && !path.contains ("\\") && !path.contains ("$") &&
                !path.contains ("`") && !path.contains ("'")) {
                return path;
            }
            var escaped = path.replace ("\\", "\\\\")
                              .replace ("\"", "\\\"")
                              .replace ("$", "\\$")
                              .replace ("`", "\\`");
            return "\"" + escaped + "\"";
        }

        public static string? first_icon_name (string? icon) {
            if (icon == null || icon == "" || icon == "application-x-executable") {
                return null;
            }
            return Path.get_basename (icon).split (".")[0];
        }
    }
}
