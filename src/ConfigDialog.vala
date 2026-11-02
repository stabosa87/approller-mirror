namespace AppRoller {
    public class ConfigDialog : Adw.Window {
        public signal void save_requested (Config config);

        private Adw.EntryRow name_row;
        private Adw.EntryRow comment_row;
        private Adw.EntryRow categories_row;
        private Adw.EntryRow arguments_row;
        private Gtk.Label error_label;
        private string? icon_source = null;

        public ConfigDialog (Adw.ApplicationWindow parent, InstalledApp app) {
            Object (title: "Configure " + app.name, transient_for: parent, modal: true,
                    default_width: 500, default_height: 600);

            var header = new Adw.HeaderBar ();
            header.title_widget = new Adw.WindowTitle ("Configure App", app.name);
            var cancel = new Gtk.Button.with_label ("Cancel");
            var save = new Gtk.Button.with_label ("Save");
            save.add_css_class ("suggested-action");
            header.pack_start (cancel);
            header.pack_end (save);

            error_label = new Gtk.Label (null);
            error_label.wrap = true;
            error_label.visible = false;
            error_label.margin_start = 24;
            error_label.margin_end = 24;
            error_label.margin_top = 12;
            error_label.add_css_class ("config-error");

            var preferences = new Adw.PreferencesPage ();
            var details = new Adw.PreferencesGroup ();
            details.title = "Application";

            name_row = new Adw.EntryRow ();
            name_row.title = "Name";
            name_row.text = app.name;
            details.add (name_row);

            comment_row = new Adw.EntryRow ();
            comment_row.title = "Description";
            comment_row.text = app.comment != null ? app.comment : "";
            details.add (comment_row);

            categories_row = new Adw.EntryRow ();
            categories_row.title = "Categories";
            categories_row.text = app.categories != null ? app.categories : "";
            categories_row.tooltip_text = "Semicolon;separated, for example Game;Emulator;";
            details.add (categories_row);

            arguments_row = new Adw.EntryRow ();
            arguments_row.title = "Launch arguments";
            arguments_row.text = app.arguments != null ? app.arguments : "";
            arguments_row.tooltip_text = "Optional flags passed before the app's file arguments.";
            details.add (arguments_row);
            preferences.add (details);

            var icon_group = new Adw.PreferencesGroup ();
            icon_group.title = "Icon";
            var icon_row = new Adw.ActionRow ();
            icon_row.title = "Application icon";
            icon_row.subtitle = "Choose a png, svg, jpreg, or xpm image.";

            var preview = new Gtk.Image ();
            preview.pixel_size = 48;
            preview.add_css_class ("app-icon");
            if (app.icon_path != null) {
                preview.set_from_file (app.icon_path);
            } else {
                var icon = app.icon != null && app.icon != "application-x-executable"
                    ? app.icon : "application-x-executable";
                preview.icon_name = icon;
            }
            icon_row.add_prefix (preview);

            var choose = new Gtk.Button.with_label ("Choose…");
            choose.add_css_class ("flat");
            choose.clicked.connect (() => choose_icon (preview));
            icon_row.add_suffix (choose);
            icon_group.add (icon_row);
            preferences.add (icon_group);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.vexpand = true;
            content.append (error_label);
            content.append (preferences);

            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (header);
            toolbar.content = content;
            this.content = toolbar;

            cancel.clicked.connect (() => this.close ());
            save.clicked.connect (() => save_requested (current_config ()));
        }

        private Config current_config () {
            var config = new Config ();
            config.name = name_row.text;
            config.comment = comment_row.text;
            config.categories = categories_row.text;
            config.arguments = arguments_row.text;
            config.icon_source = icon_source;
            return config;
        }

        private void choose_icon (Gtk.Image preview) {
            var filter = new Gtk.FileFilter ();
            filter.name = "Image files";
            string[] patterns = { "*.png", "*.svg", "*.jpg", "*.jpeg", "*.xpm" };
            foreach (var pattern in patterns) {
                filter.add_pattern (pattern);
            }
            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);

            var dialog = new Gtk.FileDialog ();
            dialog.title = "Choose an Icon";
            dialog.modal = true;
            dialog.filters = filters;
            dialog.default_filter = filter;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    var path = file.get_path ();
                    if (path != null) {
                        preview.set_from_file (path);
                        icon_source = path;
                    }
                } catch (Error e) {
                }
            });
        }

        public void show_error (string message) {
            error_label.label = message;
            error_label.visible = true;
        }
    }
}
