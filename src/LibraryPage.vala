namespace AppRoller {
    public class LibraryPage : Gtk.Box {
        public signal void configure_requested (InstalledApp app);
        public signal void delete_requested (InstalledApp app);
        public signal void launch_requested (InstalledApp app);
        public signal void install_requested ();

        public Gtk.Button refresh_button;
        private Gtk.ListBox list;
        private Adw.ActionRow add_row;

        public LibraryPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, vexpand: true);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
            content.margin_start = 24;
            content.margin_end = 24;
            content.margin_top = 18;
            content.margin_bottom = 28;

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var title = new Gtk.Label ("My Apps");
            title.add_css_class ("title-3");
            title.halign = Gtk.Align.START;

            refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
            refresh_button.add_css_class ("flat");
            refresh_button.tooltip_text = "Refresh installed apps";

            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;

            header.append (title);
            header.append (spacer);
            header.append (refresh_button);

            list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.NONE;
            list.add_css_class ("boxed-list");

            add_row = new Adw.ActionRow ();
            add_row.title = "Add application";
            add_row.subtitle = "Choose an app to install";
            add_row.activatable = true;
            var add_icon = new Gtk.Image.from_icon_name ("list-add-symbolic");
            add_icon.pixel_size = 24;
            add_icon.add_css_class ("dim-label");
            add_row.add_prefix (add_icon);
            add_row.activated.connect (() => install_requested ());
            list.append (add_row);

            content.append (header);
            content.append (list);
            append (content);
        }

        public void refresh (GLib.List<InstalledApp> apps) {
            Gtk.Widget? child;
            while ((child = list.get_first_child ()) != null) {
                list.remove (child);
            }
            add_row.subtitle = apps.length () == 0
                ? "No apps installed yet"
                : "Choose an app to install";

            foreach (var app in apps) {
                var subtitle = app.available
                    ? (app.comment != null && app.comment.strip () != "" ? app.comment : System.pretty_path (app.app_path))
                    : "Missing app: " + System.pretty_path (app.app_path);
                var row = new Adw.ActionRow ();
                row.title = app.name;
                row.subtitle = subtitle;
                row.activatable = app.available;

                var icon = new Gtk.Image ();
                icon.pixel_size = 40;
                icon.add_css_class ("library-icon");
                if (app.icon_path != null) {
                    icon.set_from_file (app.icon_path);
                } else if (app.icon != null && app.icon != "application-x-executable") {
                    icon.icon_name = app.icon;
                } else {
                    icon.icon_name = "application-x-executable";
                }
                row.add_prefix (icon);

                var configure = new Gtk.Button.with_label ("Configure");
                configure.add_css_class ("flat");
                configure.valign = Gtk.Align.CENTER;
                configure.tooltip_text = "Change the app's name, icon, or launch options";
                configure.clicked.connect (() => configure_requested (app));
                row.add_suffix (configure);

                var remove = new Gtk.Button.from_icon_name ("user-trash-symbolic");
                remove.add_css_class ("flat");
                remove.valign = Gtk.Align.CENTER;
                remove.tooltip_text = "Delete this app";
                remove.clicked.connect (() => delete_requested (app));
                row.add_suffix (remove);

                if (app.available) {
                    row.activated.connect (() => launch_requested (app));
                }
                list.append (row);
            }
            list.append (add_row);
        }
    }
}
