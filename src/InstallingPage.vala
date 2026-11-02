namespace AppRoller {
    public class InstallingPage : Gtk.Box {
        public Gtk.Spinner spinner;
        public Adw.StatusPage status;

        public InstallingPage () {
            Object (orientation: Gtk.Orientation.VERTICAL, vexpand: true);
            status = new Adw.StatusPage ();
            status.title = "Working…";
            status.description = "This may take a moment!";
            spinner = new Gtk.Spinner ();
            spinner.set_size_request (42, 42);
            spinner.halign = Gtk.Align.CENTER;
            status.child = spinner;
            append (status);
        }

        public void reset (string title, string description) {
            status.title = title;
            status.description = description;
            spinner.start ();
        }
    }
}
