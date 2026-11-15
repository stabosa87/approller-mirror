namespace AppRoller {
    public class LibraryPage : Gtk.Box {
        public signal void configure_requested (InstalledApp app);
        public signal void delete_requested (InstalledApp app);
        public signal void launch_requested (InstalledApp app);
        public signal void add_requested ();
        public signal void update_requested (InstalledApp app);

        public Gtk.Button refresh_button;
        private Gtk.ListBox list;
        private Gtk.ListBox updates_list;
        private Gtk.Box updates_section;
        private Adw.ActionRow add_row;
        private GLib.GenericArray<UpdateInfo> updates;

        public LibraryPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, vexpand: true);
            updates = new GLib.GenericArray<UpdateInfo> ();

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
            content.margin_start = 24;
            content.margin_end = 24;
            content.margin_top = 18;
            content.margin_bottom = 28;

            updates_section = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            updates_section.visible = false;
            var updates_title = new Gtk.Label ("Updates");
            updates_title.add_css_class ("title-4");
            updates_title.halign = Gtk.Align.START;
            updates_list = new Gtk.ListBox ();
            updates_list.selection_mode = Gtk.SelectionMode.NONE;
            updates_list.add_css_class ("boxed-list");
            updates_section.append (updates_title);
            updates_section.append (updates_list);

            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var title = new Gtk.Label ("My Apps");
            title.add_css_class ("title-3");
            title.halign = Gtk.Align.START;

            refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
            refresh_button.add_css_class ("flat");
            refresh_button.tooltip_text = "Refresh installed apps and check for updates";

            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;

            header.append (title);
            header.append (spacer);
            header.append (refresh_button);

            list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.NONE;
            list.add_css_class ("boxed-list");

            add_row = new Adw.ActionRow ();
            add_row.title = "Add App";
            add_row.subtitle = "Choose a file or url";
            add_row.activatable = true;
            var add_icon = new Gtk.Image.from_icon_name ("list-add-symbolic");
            add_icon.pixel_size = 24;
            add_icon.add_css_class ("dim-label");
            add_row.add_prefix (add_icon);
            add_row.activated.connect (() => add_requested ());

            content.append (updates_section);
            content.append (header);
            content.append (list);

            var scroll = new Gtk.ScrolledWindow ();
            scroll.vexpand = true;
            scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroll.set_child (content);
            append (scroll);
        }

        public void refresh (GLib.List<InstalledApp> apps, GLib.GenericArray<UpdateInfo> updates) {
            this.updates = updates;
            Gtk.Widget? child;
            while ((child = list.get_first_child ()) != null) {
                list.remove (child);
            }
            while ((child = updates_list.get_first_child ()) != null) {
                updates_list.remove (child);
            }

            updates_section.visible = updates.length > 0;
            foreach (var update in updates) {
                var baseline = update.app.version != null && update.app.version.strip () != ""
                    ? update.app.version
                    : (update.app.release_tag != null ? Forge.version_label (update.app.release_tag) : null);
                var row = new Adw.ActionRow ();
                row.title = update.app.name;
                row.subtitle = baseline != null && baseline.strip () != ""
                    ? baseline + " -> " + update.version
                    : "Version " + update.version;
                row.add_prefix (build_app_icon (update.app));

                var button = new Gtk.Button.with_label ("Update");
                button.add_css_class ("suggested-action");
                button.valign = Gtk.Align.CENTER;
                button.tooltip_text = "Download and install version " + update.version;
                button.clicked.connect (() => update_requested (update.app));
                row.add_suffix (button);
                updates_list.append (row);
            }

            foreach (var app in apps) {
                var subtitle = app.available
                    ? (app.comment != null && app.comment.strip () != "" ? app.comment : System.pretty_path (app.app_path))
                    : "Missing app: " + System.pretty_path (app.app_path);
                var row = new Adw.ActionRow ();
                row.title = app.name;
                row.subtitle = subtitle;
                row.activatable = app.available;
                row.add_prefix (build_app_icon (app));

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
            add_row.subtitle = apps.length () == 0
                ? "No apps installed yet"
                : "Choose a file or url";
            list.append (add_row);
        }

        private Gtk.Image build_app_icon (InstalledApp app) {
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
            return icon;
        }
    }
}
