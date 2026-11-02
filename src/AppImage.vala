namespace AppRoller {
    public class TempDir : GLib.Object {
        public string path;

        public TempDir () throws GLib.Error {
            path = DirUtils.make_tmp ("approller-XXXXXX");
        }

        ~TempDir () {
            DirUtils.remove (path);
        }
    }

    public class AppImage : GLib.Object {
        public string source = "";
        public string name = "";
        public string? comment = null;
        public string? version = null;
        public string slug = "";
        public string? categories = null;
        public string? mime_types = null;
        public string? keywords = null;
        public string? startup_wm_class = null;
        public bool startup_notify = false;
        public string? field_code = null;
        public uint64 size = 0;
        public uint8[]? icon_bytes = null;
        public string? icon_extension = null;
        public string? preview_path = null;
        internal TempDir? scratch = null;
    }

    public class Installed : GLib.Object {
        public string name = "";
        public string app_path = "";
        public string desktop_path = "";
        public string? icon_path = null;
    }
}
