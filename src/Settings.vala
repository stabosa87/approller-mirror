namespace AppRoller {
    public class Settings : GLib.Object {
        public bool run_in_background = false;
        public bool auto_update = false;

        public static Settings load () {
            var settings = new Settings ();
            var path = Path.build_filename (Environment.get_user_config_dir (), "approller", "settings.ini");
            if (!FileUtils.test (path, FileTest.IS_REGULAR)) {
                return settings;
            }
            try {
                string contents;
                FileUtils.get_contents (path, out contents);
                var keyfile = new KeyFile ();
                keyfile.load_from_data (contents, contents.length, KeyFileFlags.NONE);
                settings.run_in_background = keyfile.get_boolean ("general", "run-in-background");
                settings.auto_update = keyfile.get_boolean ("general", "auto-update");
            } catch (Error e) {
            }
            return settings;
        }

        public void save () throws FileError {
            var dir = Path.build_filename (Environment.get_user_config_dir (), "approller");
            DirUtils.create_with_parents (dir, 0755);
            var keyfile = new KeyFile ();
            keyfile.set_boolean ("general", "run-in-background", run_in_background);
            keyfile.set_boolean ("general", "auto-update", auto_update);
            FileUtils.set_contents (Path.build_filename (dir, "settings.ini"), keyfile.to_data ());
        }
    }
}
