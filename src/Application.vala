namespace AppRoller {
    public const string APP_ID = "ing.stab.AppRoller";

    public class Application : Adw.Application {
        private Window? window = null;
        private Settings settings = new Settings ();
        private TrayIcon? tray = null;
        private bool started = false;

        public Application () {
            Object (application_id: APP_ID, flags: ApplicationFlags.HANDLES_OPEN);
        }

        protected override void startup () {
            base.startup ();
            settings = Settings.load ();
            tray = new TrayIcon ();
            tray.activate_requested.connect (show_window);
            var about = new GLib.SimpleAction ("about", null);
            about.activate.connect (show_about);
            add_action (about);
            var quit_action = new GLib.SimpleAction ("quit", null);
            quit_action.activate.connect (() => { this.quit (); });
            add_action (quit_action);
        }

        protected override void activate () {
            var first_activation = !started;
            ensure_window ();
            started = true;
            if (first_activation && settings.run_in_background && tray != null && tray.available) {
                return;
            }
            window.present ();
        }

        protected override void open (GLib.File[] files, string hint) {
            ensure_window ();
            started = true;
            window.handle_open_files (files);
            window.present ();
        }

        private void ensure_window () {
            if (window == null) {
                window = new Window (this, settings);
                window.background_available = tray != null && tray.available;
                load_css ();
            }
        }

        private void show_window () {
            ensure_window ();
            window.present ();
        }

        private void show_about () {
            var about = new Adw.AboutWindow ();
            about.transient_for = window;
            about.modal = true;
            about.application_name = "AppRoller";
            about.application_icon = APP_ID;
            about.developer_name = "stabosa87";
            about.version = VERSION;
            about.comments = "Install and manage apps.";
            about.license_type = Gtk.License.MIT_X11;
            about.issue_url = "https://git.stab.ing/stabosa87/approller/";
            about.present ();
        }

        private static void load_css () {
            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/ing/stab/AppRoller/style.css");
            var display = Gdk.Display.get_default ();
            if (display != null) {
                Gtk.StyleContext.add_provider_for_display (display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }
        }
    }

    public static int main (string[] args) {
        return new Application ().run (args);
    }
}
