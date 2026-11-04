namespace AppRoller {
    public class Window : Adw.ApplicationWindow {
        private Gtk.Stack stack;
        private Adw.ToastOverlay toast_overlay;
        private LibraryPage library;
        private ReadyPage ready;
        private InstallingPage installing_page;
        private DonePage done;
        private ErrorPage error_page;
        private AppImage? inspection = null;
        private Installed? installed = null;
        private string? retry_path = null;
        private bool retry_install = false;
        private bool installing_now = false;
        private bool opened_with_file = false;
        private uint request_id = 0;
        private Adw.Window? config_window = null;

        public Window (Application app) {
            Object (application: app, title: "AppRoller", default_width: 560, default_height: 720);
            this.icon_name = APP_ID;

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.transition_duration = 140;
            stack.vexpand = true;

            library = new LibraryPage ();
            ready = new ReadyPage ();
            installing_page = new InstallingPage ();
            done = new DonePage ();
            error_page = new ErrorPage ();

            stack.add_named (library, "library");
            stack.add_named (ready, "ready");
            stack.add_named (installing_page, "installing");
            stack.add_named (done, "done");
            stack.add_named (error_page, "error");
            stack.visible_child_name = "library";

            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.child = stack;

            var header = new Adw.HeaderBar ();
            header.title_widget = new Adw.WindowTitle ("AppRoller", "Install and manage apps");

            var menu = new GLib.Menu ();
            menu.append ("Choose File…", "win.choose-file");
            menu.append ("Refresh My Apps", "win.refresh-library");
            menu.append ("Open Applications Folder", "win.open-applications");
            menu.append ("About AppRoller", "app.about");
            menu.append ("Quit", "app.quit");
            var menu_button = new Gtk.MenuButton ();
            menu_button.icon_name = "open-menu-symbolic";
            menu_button.menu_model = menu;
            menu_button.tooltip_text = "Main Menu";
            menu_button.add_css_class ("flat");
            header.pack_end (menu_button);

            var toolbar = new Adw.ToolbarView ();
            toolbar.add_top_bar (header);
            toolbar.content = toast_overlay;
            this.content = toolbar;

            setup_actions (app);
            setup_signals ();

            refresh_library ();
            stack.visible_child_name = "library";
        }

        private void setup_actions (Application app) {
            var choose = new SimpleAction ("choose-file", null);
            choose.activate.connect (choose_file);
            this.add_action (choose);
            var refresh = new SimpleAction ("refresh-library", null);
            refresh.activate.connect (refresh_library);
            this.add_action (refresh);
            var open = new SimpleAction ("open-applications", null);
            open.activate.connect (() => System.open_directory (System.applications_dir ()));
            this.add_action (open);

            app.set_accels_for_action ("win.choose-file", { "<Control>o" });
            app.set_accels_for_action ("win.refresh-library", { "<Control>r" });
            app.set_accels_for_action ("app.quit", { "<Control>q" });
        }

        private void setup_signals () {
            library.install_requested.connect (choose_file);
            library.refresh_button.clicked.connect (refresh_library);
            library.configure_requested.connect (open_config);
            library.delete_requested.connect (confirm_delete);
            library.launch_requested.connect (launch_app);

            ready.choose_requested.connect (choose_file);
            ready.install_requested.connect (begin_install);
            ready.dropped.connect (handle_target_drop);

            done.launch_requested.connect (launch_installed);
            done.reveal_requested.connect (reveal_installed);
            done.back_requested.connect (reset_to_library);

            error_page.choose_requested.connect (choose_file);
            error_page.retry_requested.connect (retry);

            this.close_request.connect (() => {
                if (installing_now) {
                    toast ("Installation in progress. Please wait…");
                    return true;
                }
                return false;
            });
        }

        public void handle_open_files (GLib.File[] files) {
            opened_with_file = true;
            string[] paths = {};
            foreach (var file in files) {
                var path = file.get_path ();
                if (path != null) {
                    paths += path;
                }
            }
            accept_paths (paths);
        }

        private void accept_paths (string[] paths) {
            foreach (var path in paths) {
                if (Installer.looks_like_appimage (path)) {
                    begin_inspect (path);
                    return;
                }
            }
            toast ("Choose a supported app file to install it.");
        }

        private void choose_file () {
            if (installing_now) {
                toast ("Installation in progress. Please wait…");
                return;
            }
            opened_with_file = false;
            var filter = new Gtk.FileFilter ();
            filter.name = "Application files";
            filter.add_pattern ("*.AppImage");
            filter.add_pattern ("*.appimage");
            filter.add_mime_type ("application/x-appimage");
            filter.add_mime_type ("application/x-executable");
            var all = new Gtk.FileFilter ();
            all.name = "All files";
            all.add_pattern ("*");
            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);
            filters.append (all);
            var dialog = new Gtk.FileDialog ();
            dialog.title = "Choose an app";
            dialog.modal = true;
            dialog.filters = filters;
            dialog.default_filter = filter;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    var path = file.get_path ();
                    if (path != null && Installer.looks_like_appimage (path)) {
                        begin_inspect (path);
                    } else {
                        toast ("That file isn't a supported app.");
                    }
                } catch (Error e) {
                }
            });
        }

        private void begin_inspect (string path) {
            if (!Installer.looks_like_appimage (path)) {
                toast ("That file isn't a supported app.");
                return;
            }
            inspection = null;
            installed = null;
            retry_path = null;
            retry_install = false;
            request_id += 1;
            var request = request_id;
            use_installer_size ();
            installing_page.reset ("Reading " + Path.get_basename (path) + "…", "Looking for the app's name, icon and version.");
            stack.visible_child_name = "installing";

            new Thread<void*> ("inspect", () => {
                AppImage? app = null;
                string? error = null;
                try {
                    app = Installer.inspect (path);
                } catch (AppRollerError e) {
                    error = e.message;
                }
                Idle.add (() => {
                    if (request == this.request_id) {
                        if (app != null) {
                            show_ready (app);
                        } else {
                            retry_path = path;
                            retry_install = false;
                            show_error ("Couldn't read that app", error != null ? error : "Unknown error");
                        }
                    }
                    return false;
                });
                return null;
            });
        }

        private void show_ready (AppImage app) {
            inspection = app;
            ready.drag_source_path = app.source;
            if (app.preview_path != null) {
                ready.icon.set_from_file (app.preview_path);
                ready.icon.pixel_size = 128;
            } else {
                ready.icon.icon_name = "application-x-executable";
                ready.icon.pixel_size = 96;
            }
            ready.name_label.label = app.name;
            if (app.comment != null && app.comment.strip () != "") {
                ready.comment_label.label = app.comment;
                ready.comment_label.visible = true;
            } else {
                ready.comment_label.visible = false;
            }
            var meta = System.human_size (app.size);
            if (app.version != null) {
                meta += "  -  Version " + app.version;
            }
            ready.meta_label.label = meta;
            var target = Installer.target_path (app);
            var replacing = FileUtils.test (target, FileTest.EXISTS);
            var existing_version = Apps.installed_version (target);
            var upgrading = replacing && existing_version != null && app.version != null &&
                            existing_version != app.version;
            ready.install_button.label = upgrading ? "Upgrade" : (replacing ? "Replace" : "Install");
            ready.choose_button.visible = !opened_with_file;
            ready.hint_label.label = upgrading
                ? "Drag the app onto Applications to upgrade the installed copy, or click Upgrade."
                : replacing
                    ? "Drag the app onto Applications to replace the installed copy, or click Replace."
                    : "Drag the app onto Applications to install it, or click Install.";
            use_installer_size ();
            stack.visible_child_name = "ready";
        }

        private void begin_install () {
            if (installing_now || inspection == null) {
                return;
            }
            var app = inspection;
            inspection = null;
            installing_now = true;
            installed = null;
            retry_install = true;
            installing_page.reset ("Installing " + app.name + "…", "Installing the app.");
            use_installer_size ();
            stack.visible_child_name = "installing";

            new Thread<void*> ("install", () => {
                Installed? result = null;
                string? error = null;
                try {
                    result = Installer.install (app);
                } catch (AppRollerError e) {
                    error = e.message;
                }
                Idle.add (() => {
                    installing_now = false;
                    if (result != null) {
                        installed = result;
                        refresh_library ();
                        show_done (result);
                    } else {
                        inspection = app;
                        retry_install = true;
                        show_error ("Installation failed", error != null ? error : "Unknown error");
                    }
                    return false;
                });
                return null;
            });
        }

        private void show_done (Installed result) {
            done.title_label.label = result.name + " is installed";
            if (result.icon_path != null) {
                done.app_icon.set_from_file (result.icon_path);
                done.app_icon.visible = true;
                done.check_icon.visible = false;
            } else {
                done.app_icon.visible = false;
                done.check_icon.visible = true;
            }
            use_installer_size ();
            stack.visible_child_name = "done";
        }

        private void show_error (string title, string message) {
            error_page.set_error (title, message);
            error_page.retry_button.visible = retry_path != null || retry_install;
            error_page.choose_button.visible = !opened_with_file;
            use_installer_size ();
            stack.visible_child_name = "error";
        }

        private void refresh_library () {
            library.refresh (Apps.list ());
        }

        private void reset_to_library () {
            request_id += 1;
            opened_with_file = false;
            inspection = null;
            installed = null;
            retry_path = null;
            retry_install = false;
            refresh_library ();
            use_library_size ();
            stack.visible_child_name = "library";
        }

        private void retry () {
            if (retry_install && inspection != null) {
                begin_install ();
            } else if (retry_path != null) {
                var path = retry_path;
                begin_inspect (path);
            } else {
                choose_file ();
            }
        }

        private void handle_target_drop (string path) {
            if (!Installer.looks_like_appimage (path)) {
                toast ("Drop a supported app onto Applications to install it.");
                return;
            }
            if (inspection != null && inspection.source == Filename.canonicalize (path)) {
                begin_install ();
            } else {
                opened_with_file = false;
                begin_inspect (path);
            }
        }

        private void launch_app (InstalledApp app) {
            try {
                System.launch_desktop_entry (app.desktop_path);
                toast ("Launching " + app.name + "…");
            } catch (Error e) {
                toast ("Couldn't launch " + app.name + ": " + e.message);
            }
        }

        private void launch_installed () {
            if (installed == null) {
                return;
            }
            try {
                System.launch_desktop_entry (installed.desktop_path);
                toast ("Launching…");
            } catch (Error e) {
                toast ("Couldn't launch the app: " + e.message);
            }
        }

        private void reveal_installed () {
            if (installed != null) {
                System.show_in_files (installed.app_path);
            }
        }

        private void confirm_delete (InstalledApp app) {
            var dialog = new Adw.MessageDialog (this, "Delete " + app.name + "?", "This removes the app, its desktop entry, and its icon from this computer.");
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("delete", "Delete");
            dialog.set_response_appearance ("delete", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.set_default_response ("cancel");
            dialog.set_close_response ("cancel");
            dialog.response.connect ((response) => {
                if (response == "delete") {
                    try {
                        Apps.remove (app);
                        toast ("Deleted " + app.name);
                        refresh_library ();
                    } catch (AppRollerError e) {
                        toast (e.message);
                    }
                }
                dialog.close ();
            });
            dialog.present ();
        }

        private void open_config (InstalledApp app) {
            if (config_window != null) {
                config_window.present ();
                return;
            }
            var dialog = new ConfigDialog (this, app);
            config_window = dialog;
            dialog.close_request.connect (() => {
                config_window = null;
                return false;
            });
            dialog.save_requested.connect ((config) => {
                try {
                    Apps.save_config (app, config);
                    toast ("Saved " + config.name);
                    refresh_library ();
                    dialog.close ();
                } catch (AppRollerError e) {
                    dialog.show_error (e.message);
                }
            });
            dialog.present ();
        }

        private void use_installer_size () {
            set_default_size (820, 520);
        }

        private void use_library_size () {
            set_default_size (560, 720);
        }

        private void toast (string message) {
            var t = new Adw.Toast (message);
            t.timeout = 4;
            toast_overlay.add_toast (t);
        }
    }
}
