namespace AppRoller {
    public class AddDialog : Adw.Window {
        public signal void file_requested ();
        public signal void link_requested ();

        public AddDialog (Adw.ApplicationWindow parent) {
            Object (title: "Add App", transient_for: parent, modal: true,
                    default_width: 520, default_height: 360);

            var header = new Adw.HeaderBar ();
            header.title_widget = new Adw.WindowTitle ("Add App", "Choose where the app comes from");
            var cancel = new Gtk.Button.with_label ("Cancel");
            header.pack_start (cancel);

            var page = new Adw.PreferencesPage ();
            var group = new Adw.PreferencesGroup ();
            group.title = "Add App";
            group.description = "Choose an AppImage file or paste a link.";

            var file_row = new Adw.ActionRow ();
            file_row.title = "From a file";
            file_row.subtitle = "Choose an AppImage on this computer.";
            file_row.activatable = true;
            var file_icon = new Gtk.Image.from_icon_name ("document-open-symbolic");
            file_icon.pixel_size = 24;
            file_icon.add_css_class ("dim-label");
            file_row.add_prefix (file_icon);
            file_row.activated.connect (() => file_requested ());
            group.add (file_row);

            var link_row = new Adw.ActionRow ();
            link_row.title = "From a url";
            link_row.subtitle = "Use a git forge repository or a direct AppImage link.";
            link_row.activatable = true;
            var link_icon = new Gtk.Image.from_icon_name ("web-browser-symbolic");
            link_icon.pixel_size = 24;
            link_icon.add_css_class ("dim-label");
            link_row.add_prefix (link_icon);
            link_row.activated.connect (() => link_requested ());
            group.add (link_row);

            page.add (group);

            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (header);
            toolbar.content = page;
            this.content = toolbar;

            cancel.clicked.connect (() => this.close ());
        }
    }
}
