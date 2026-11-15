namespace AppRoller {
    [DBus (name = "org.kde.StatusNotifierItem")]
    private class TrayItem : GLib.Object {
        [DBus (visible = false)]
        public signal void activated ();

        [DBus (name = "Category")]
        public string category { owned get { return "ApplicationStatus"; } }

        [DBus (name = "Id")]
        public string id { owned get { return APP_ID; } }

        [DBus (name = "Title")]
        public string title { owned get { return "AppRoller"; } }

        [DBus (name = "Status")]
        public string status { owned get { return "Active"; } }

        [DBus (name = "WindowId")]
        public int window_id { get { return 0; } }

        [DBus (name = "IconName")]
        public string icon_name { owned get { return APP_ID; } }

        [DBus (name = "OverlayIconName")]
        public string overlay_icon_name { owned get { return ""; } }

        [DBus (name = "AttentionIconName")]
        public string attention_icon_name { owned get { return ""; } }

        [DBus (name = "AttentionMovieName")]
        public string attention_movie_name { owned get { return ""; } }

        [DBus (name = "ItemIsMenu")]
        public bool item_is_menu { get { return false; } }

        [DBus (name = "Menu")]
        public GLib.ObjectPath menu { owned get { return new GLib.ObjectPath ("/NO_DBUSMENU"); } }

        [DBus (name = "Activate")]
        public void activate (int x, int y) throws GLib.Error {
            activated ();
        }

        [DBus (name = "SecondaryActivate")]
        public void secondary_activate (int x, int y) throws GLib.Error {
            activated ();
        }

        [DBus (name = "ContextMenu")]
        public void context_menu (int x, int y) throws GLib.Error {
            activated ();
        }

        [DBus (name = "Scroll")]
        public void scroll (int delta, string orientation) throws GLib.Error {
        }
    }

    public class TrayIcon : GLib.Object {
        public signal void activate_requested ();
        public bool available = false;

        private GLib.DBusConnection? connection = null;
        private TrayItem? item = null;

        public TrayIcon () {
            try {
                connection = GLib.Bus.get_sync (GLib.BusType.SESSION, null);
                item = new TrayItem ();
                item.activated.connect (() => activate_requested ());
                connection.register_object ("/StatusNotifierItem", item);
                connection.call_sync ("org.kde.StatusNotifierWatcher",
                                      "/StatusNotifierWatcher",
                                      "org.kde.StatusNotifierWatcher",
                                      "RegisterStatusNotifierItem",
                                      new GLib.Variant ("(s)", "/StatusNotifierItem"),
                                      null,
                                      GLib.DBusCallFlags.NO_AUTO_START,
                                      1000,
                                      null);
                available = true;
            } catch (Error e) {
                available = false;
            }
        }
    }
}
