namespace AppRoller {
    public class SettingsPage : Adw.PreferencesPage {
        public signal void settings_changed (Settings settings);

        private Settings settings;
        private Adw.SwitchRow background_row;
        private Adw.SwitchRow auto_row;

        public SettingsPage (Settings settings) {
            this.settings = settings;

            var group = new Adw.PreferencesGroup ();
            group.title = "General";

            background_row = new Adw.SwitchRow ();
            background_row.title = "Run in background";
            background_row.subtitle = "Start hidden and keep checking for updates.";
            background_row.active = settings.run_in_background;
            group.add (background_row);

            auto_row = new Adw.SwitchRow ();
            auto_row.title = "Auto update";
            auto_row.subtitle = "Install updates automatically when they are found.";
            auto_row.active = settings.auto_update;
            group.add (auto_row);

            add (group);

            background_row.notify["active"].connect (() => {
                settings.run_in_background = background_row.active;
                settings_changed (settings);
            });
            auto_row.notify["active"].connect (() => {
                settings.auto_update = auto_row.active;
                settings_changed (settings);
            });
        }
    }
}
