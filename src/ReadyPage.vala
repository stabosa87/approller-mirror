namespace AppRoller {
    public class ReadyPage : Gtk.Box {
        public signal void choose_requested ();
        public signal void install_requested ();
        public signal void dropped (string path);

        public Gtk.Image icon;
        public Gtk.Box target;
        public Gtk.Label name_label;
        public Gtk.Label comment_label;
        public Gtk.Label hint_label;
        public Gtk.Label meta_label;
        public Gtk.Label destination_label;
        public Gtk.Button install_button;
        public Gtk.Button choose_button;
        public string? drag_source_path = null;

        public ReadyPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 12,
                    halign: Gtk.Align.CENTER, valign: Gtk.Align.CENTER,
                    margin_start: 36, margin_end: 36, margin_top: 24, margin_bottom: 36);

            name_label = heading ("App");
            comment_label = body_label ("");
            comment_label.visible = false;

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 20);
            row.halign = Gtk.Align.CENTER;
            row.valign = Gtk.Align.CENTER;

            icon = new Gtk.Image ();
            icon.pixel_size = 128;
            icon.add_css_class ("app-icon");
            icon.valign = Gtk.Align.CENTER;

            var arrow = icon_widget ("go-next-symbolic", 24, "dim-label");

            target = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            target.set_size_request (154, 154);
            target.add_css_class ("drop-zone");
            target.add_css_class ("install-target");

            var target_content = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            target_content.halign = Gtk.Align.CENTER;
            target_content.valign = Gtk.Align.CENTER;
            target_content.vexpand = true;
            target_content.append (icon_widget ("folder-symbolic", 52, "dim-label"));
            var target_label = new Gtk.Label ("Applications");
            target_label.add_css_class ("title-4");
            var target_hint = new Gtk.Label ("in your home");
            target_hint.add_css_class ("caption");
            target_hint.add_css_class ("dim-label");
            target_content.append (target_label);
            target_content.append (target_hint);
            target.append (target_content);

            row.append (icon);
            row.append (arrow);
            row.append (target);

            hint_label = new Gtk.Label ("Drag the app onto Applications to install it, or click Install.");
            hint_label.wrap = true;
            hint_label.justify = Gtk.Justification.CENTER;
            hint_label.max_width_chars = 42;

            meta_label = new Gtk.Label (null);
            meta_label.add_css_class ("caption");
            meta_label.add_css_class ("dim-label");

            destination_label = new Gtk.Label (null);
            destination_label.add_css_class ("caption");
            destination_label.add_css_class ("dim-label");
            destination_label.ellipsize = Pango.EllipsizeMode.MIDDLE;

            install_button = new Gtk.Button.with_label ("Install");
            install_button.add_css_class ("suggested-action");
            install_button.set_size_request (140, -1);
            install_button.clicked.connect (() => install_requested ());

            choose_button = new Gtk.Button.with_label ("Choose Another File…");
            choose_button.add_css_class ("flat");
            choose_button.clicked.connect (() => choose_requested ());

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            buttons.halign = Gtk.Align.CENTER;
            buttons.append (install_button);
            buttons.append (choose_button);

            append (name_label);
            append (comment_label);
            append (row);
            append (hint_label);
            append (meta_label);
            append (destination_label);
            append (buttons);

            setup_drop_target ();
            setup_drag_source ();
        }

        private void setup_drop_target () {
            var drop = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            drop.enter.connect ((x, y) => {
                target.add_css_class ("drag-hover");
                return Gdk.DragAction.COPY;
            });
            drop.leave.connect (() => target.remove_css_class ("drag-hover"));
            drop.drop.connect ((value, x, y) => {
                target.remove_css_class ("drag-hover");
                var files = (Gdk.FileList) value.get_boxed ();
                if (files != null) {
                    foreach (var file in files.get_files ()) {
                        var path = file.get_path ();
                        if (path != null) {
                            dropped (path);
                            return true;
                        }
                    }
                }
                return false;
            });
            target.add_controller (drop);
        }

        private void setup_drag_source () {
            icon.set_cursor_from_name ("grab");
            var source = new Gtk.DragSource ();
            source.actions = Gdk.DragAction.COPY;
            source.prepare.connect ((x, y) => {
                if (drag_source_path == null) {
                    return null;
                }
                var value = GLib.Value (typeof (GLib.File));
                value.set_object ((GLib.Object) File.new_for_path (drag_source_path));
                return new Gdk.ContentProvider.for_value (value);
            });
            icon.add_controller (source);
        }
    }
}
