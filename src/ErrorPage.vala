namespace AppRoller {
    public class ErrorPage : Gtk.Box {
        public Gtk.Button retry_button;
        public Gtk.Button choose_button;
        public Adw.StatusPage status;

        public ErrorPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, vexpand: true);
            status = new Adw.StatusPage ();
            status.title = "Something went wrong";
            status.icon_name = "dialog-error-symbolic";

            retry_button = new Gtk.Button.with_label ("Try Again");
            retry_button.add_css_class ("suggested-action");
            retry_button.clicked.connect (() => retry_requested ());

            choose_button = new Gtk.Button.with_label ("Choose Another File…");
            choose_button.add_css_class ("flat");
            choose_button.clicked.connect (() => choose_requested ());

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            buttons.halign = Gtk.Align.CENTER;
            buttons.append (retry_button);
            buttons.append (choose_button);
            status.child = buttons;
            append (status);
        }

        public signal void retry_requested ();
        public signal void choose_requested ();

        public void set_error (string title, string message) {
            status.title = title;
            status.description = message;
        }
    }
}
