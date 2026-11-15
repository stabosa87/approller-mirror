namespace AppRoller {
    public class AssetDialog : Adw.Window {
        public signal void chosen (ReleaseAsset asset);

        private GLib.GenericArray<ReleaseAsset> assets;
        private Gtk.ListBox list;
        private Gtk.Button continue_button;
        private ReleaseAsset? selected = null;

        public AssetDialog (Adw.ApplicationWindow parent, string title, string description,
                            GLib.GenericArray<ReleaseAsset> assets, ReleaseAsset? preferred) {
            Object (title: title, transient_for: parent, modal: true,
                    default_width: 600, default_height: 520);
            this.assets = assets;

            var header = new Adw.HeaderBar ();
            header.title_widget = new Adw.WindowTitle (title, "Multiple AppImages found");
            var cancel = new Gtk.Button.with_label ("Cancel");
            header.pack_start (cancel);

            continue_button = new Gtk.Button.with_label ("Continue");
            continue_button.add_css_class ("suggested-action");
            continue_button.sensitive = false;
            continue_button.valign = Gtk.Align.CENTER;
            header.pack_end (continue_button);

            var intro = new Gtk.Label (description);
            intro.wrap = true;
            intro.halign = Gtk.Align.START;
            intro.add_css_class ("dim-label");

            list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.SINGLE;
            list.add_css_class ("boxed-list");

            var recommended = preferred != null ? preferred : Forge.recommended_asset (assets);
            int recommended_index = -1;
            for (int i = 0; i < assets.length; i++) {
                var asset = assets.get ((uint) i);
                var row = new Adw.ActionRow ();
                var display_name = asset.name.strip ();
                if (display_name == "") {
                    display_name = Forge.file_name_from_url (asset.url);
                }
                row.title = display_name;
                var meta = asset.size > 0 ? System.human_size ((uint64) asset.size) : "Size unknown";
                meta += "  -  " + Forge.asset_arch_label (asset);
                row.subtitle = meta;
                row.activatable = true;

                var icon = new Gtk.Image.from_icon_name ("application-x-executable");
                icon.pixel_size = 24;
                icon.add_css_class ("dim-label");
                row.add_prefix (icon);

                if (asset == recommended) {
                    var badge = new Gtk.Label ("Recommended");
                    badge.add_css_class ("caption");
                    badge.add_css_class ("dim-label");
                    badge.valign = Gtk.Align.CENTER;
                    row.add_suffix (badge);
                    recommended_index = i;
                }
                list.append (row);
            }

            var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            content.margin_start = 18;
            content.margin_end = 18;
            content.margin_top = 18;
            content.margin_bottom = 18;
            content.append (intro);

            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.vexpand = true;
            scrolled.set_child (list);
            content.append (scrolled);

            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (header);
            toolbar.content = content;
            this.content = toolbar;

            list.row_selected.connect ((row) => {
                if (row == null) {
                    selected = null;
                    continue_button.sensitive = false;
                    return;
                }
                int index = row.get_index ();
                if (index >= 0 && index < assets.length) {
                    selected = assets.get ((uint) index);
                    continue_button.sensitive = true;
                }
            });
            list.row_activated.connect ((row) => {
                int index = row.get_index ();
                if (index >= 0 && index < assets.length) {
                    submit (assets.get ((uint) index));
                }
            });

            if (recommended_index >= 0) {
                var row = list.get_row_at_index (recommended_index);
                if (row != null) {
                    list.select_row (row);
                }
            }

            cancel.clicked.connect (() => this.close ());
            continue_button.clicked.connect (() => {
                if (selected != null) {
                    submit (selected);
                }
            });
        }

        private void submit (ReleaseAsset asset) {
            chosen (asset);
            this.close ();
        }
    }
}
