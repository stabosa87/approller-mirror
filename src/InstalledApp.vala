namespace AppRoller {
    public class InstalledApp : GLib.Object {
        public string name = "";
        public string? comment = null;
        public string slug = "";
        public string? version = null;
        public string? categories = null;
        public string? field_code = null;
        public string? arguments = null;
        public string app_path = "";
        public string desktop_path = "";
        public string? icon = null;
        public string? icon_path = null;
        public string? source_url = null;
        public string? release_tag = null;
        public string? asset_name = null;
        public bool available = false;
    }

    public class Config : GLib.Object {
        public string name = "";
        public string comment = "";
        public string categories = "";
        public string arguments = "";
        public string? icon_source = null;
        public string? source_url = null;
        public string? release_tag = null;
        public string? asset_name = null;
    }
}
