namespace AppRoller {
    public class DonePage : Gtk.Box {
        public signal void launch_requested ();
        public signal void reveal_requested ();
        public signal void back_requested ();

        public Gtk.Image app_icon;
        public Gtk.Image check_icon;
        public Gtk.Label title_label;
        public Gtk.Label subtitle_label;
        public Gtk.Label details_label;

        public DonePage () {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 16,
                    halign: Gtk.Align.CENTER, valign: Gtk.Align.CENTER,
                    margin_start: 36, margin_end: 36, margin_top: 24, margin_bottom: 36);

            app_icon = new Gtk.Image ();
            app_icon.pixel_size = 96;
            app_icon.add_css_class ("app-icon");
            app_icon.visible = false;

            check_icon = icon_widget ("emblem-ok-symbolic", 88, "success-icon");
            title_label = heading ("Installed");
            subtitle_label = body_label ("It should now appear in your app grid.");

            details_label = new Gtk.Label (null);
            details_label.add_css_class ("caption");
            details_label.add_css_class ("dim-label");
            details_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            details_label.max_width_chars = 48;

            var launch = new Gtk.Button.with_label ("Launch");
            launch.add_css_class ("suggested-action");
            launch.set_size_request (120, -1);
            launch.clicked.connect (() => launch_requested ());

            var reveal = new Gtk.Button.with_label ("Show in Files");
            reveal.clicked.connect (() => reveal_requested ());

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            buttons.halign = Gtk.Align.CENTER;
            buttons.append (launch);
            buttons.append (reveal);

            var back = new Gtk.Button.with_label ("Back to My Apps");
            back.add_css_class ("flat");
            back.halign = Gtk.Align.CENTER;
            back.clicked.connect (() => back_requested ());

            append (app_icon);
            append (check_icon);
            append (title_label);
            append (subtitle_label);
            append (details_label);
            append (buttons);
            append (back);
        }
    }
}
