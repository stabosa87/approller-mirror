namespace AppRoller {
    public class UrlDialog : Adw.Window {
        public signal void submitted (string url);

        private Adw.EntryRow url_row;
        private Gtk.Button add_button;
        private Gtk.Label error_label;

        public UrlDialog (Adw.ApplicationWindow parent) {
            Object (title: "Add from url", transient_for: parent, modal: true,
                    default_width: 540, default_height: 380);

            var header = new Adw.HeaderBar ();
            header.title_widget = new Adw.WindowTitle ("Add from url", "Git forge or AppImage link");
            var cancel = new Gtk.Button.with_label ("Cancel");
            header.pack_start (cancel);

            error_label = new Gtk.Label (null);
            error_label.wrap = true;
            error_label.visible = false;
            error_label.margin_start = 24;
            error_label.margin_end = 24;
            error_label.margin_top = 12;
            error_label.add_css_class ("config-error");

            var page = new Adw.PreferencesPage ();
            var group = new Adw.PreferencesGroup ();
            group.title = "Link";
            group.description = "Paste a GitHub, GitLab, Codeberg or other forge repository to install its latest AppImage, or a direct .AppImage link.";

            url_row = new Adw.EntryRow ();
            url_row.title = "URL";
            url_row.text = "";
            group.add (url_row);
            page.add (group);

            add_button = new Gtk.Button.with_label ("Continue");
            add_button.add_css_class ("suggested-action");
            add_button.sensitive = false;
            add_button.valign = Gtk.Align.CENTER;
            header.pack_end (add_button);

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content.vexpand = true;
            content.append (error_label);
            content.append (page);

            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (header);
            toolbar.content = content;
            this.content = toolbar;

            url_row.changed.connect (() => {
                add_button.sensitive = url_row.text.strip () != "";
                hide_error ();
            });
            cancel.clicked.connect (() => this.close ());
            add_button.clicked.connect (submit);
        }

        private void submit () {
            var url = url_row.text.strip ();
            if (url == "") {
                show_error ("Paste a link first.");
                return;
            }
            var lower = url.down ();
            if (!lower.has_prefix ("http://") && !lower.has_prefix ("https://") && !lower.has_prefix ("git@")) {
                int slash = lower.index_of ("/");
                var first = slash >= 0 ? lower.substring (0, slash) : lower;
                if (first.contains (".")) {
                    url = "https://" + url;
                } else {
                    show_error ("Use an http:// or https:// link, or a forge url such as github.com/owner/repo.");
                    return;
                }
            }
            submitted (url);
        }

        public void show_error (string message) {
            error_label.label = message;
            error_label.visible = true;
        }

        private void hide_error () {
            error_label.visible = false;
        }
    }
}
