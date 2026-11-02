namespace AppRoller {
    internal Gtk.Label heading (string text) {
        var label = new Gtk.Label (text);
        label.wrap = true;
        label.justify = Gtk.Justification.CENTER;
        label.max_width_chars = 34;
        label.add_css_class ("title-1");
        return label;
    }

    internal Gtk.Label body_label (string text) {
        var label = new Gtk.Label (text);
        label.wrap = true;
        label.justify = Gtk.Justification.CENTER;
        label.max_width_chars = 42;
        label.add_css_class ("dim-label");
        return label;
    }

    internal Gtk.Image icon_widget (string name, int size, string css_class) {
        var image = new Gtk.Image.from_icon_name (name);
        image.pixel_size = size;
        if (css_class != "") {
            image.add_css_class (css_class);
        }
        return image;
    }
}
