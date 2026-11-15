namespace AppRoller {
    public class Window : Adw.ApplicationWindow {
        private Gtk.Stack stack;
        private Adw.ToastOverlay toast_overlay;
        private LibraryPage library;
        private SettingsPage settings_page;
        private ReadyPage ready;
        private InstallingPage installing_page;
        private DonePage done;
        private ErrorPage error_page;
        private Settings settings = new Settings ();
        private Gtk.Button back_button;
        private AppImage? inspection = null;
        private Installed? installed = null;
        private string? retry_path = null;
        private string? retry_url = null;
        private UpdateInfo? retry_update = null;
        private bool retry_install = false;
        private bool installing_now = false;
        private bool opened_with_file = false;
        private uint request_id = 0;
        private Adw.Window? config_window = null;
        private UrlDialog? url_dialog = null;
        private AddDialog? add_dialog = null;
        private AssetDialog? asset_dialog = null;
        private ForgeRepo? pending_repo = null;
        private ReleaseInfo? pending_release = null;
        private UpdateInfo? pending_update = null;
        private GLib.GenericArray<UpdateInfo> updates;
        private bool updates_checking = false;
        private bool auto_updating = false;
        public bool background_available = false;

        public Window (Application app, Settings settings) {
            Object (application: app, title: "AppRoller", default_width: 560, default_height: 720);
            this.icon_name = APP_ID;
            this.settings = settings;
            updates = new GLib.GenericArray<UpdateInfo> ();

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            stack.transition_duration = 140;
            stack.vexpand = true;

            library = new LibraryPage ();
            settings_page = new SettingsPage (settings);
            ready = new ReadyPage ();
            installing_page = new InstallingPage ();
            done = new DonePage ();
            error_page = new ErrorPage ();

            stack.add_named (library, "library");
            stack.add_named (settings_page, "settings");
            stack.add_named (ready, "ready");
            stack.add_named (installing_page, "installing");
            stack.add_named (done, "done");
            stack.add_named (error_page, "error");
            stack.visible_child_name = "library";

            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.child = stack;

            var header = new Adw.HeaderBar ();
            header.title_widget = new Adw.WindowTitle ("AppRoller", "Install and manage apps");

            back_button = new Gtk.Button.from_icon_name ("go-previous-symbolic");
            back_button.add_css_class ("flat");
            back_button.tooltip_text = "Back to My Apps";
            back_button.visible = false;
            back_button.clicked.connect (reset_to_library);
            header.pack_start (back_button);

            var menu = new GLib.Menu ();
            menu.append ("Add App...", "win.add-app");
            menu.append ("Refresh My Apps", "win.refresh-library");
            menu.append ("Open Applications Folder", "win.open-applications");
            menu.append ("Settings", "win.settings");
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
            GLib.Idle.add (() => {
                check_for_updates (false);
                return false;
            });
            GLib.Timeout.add_seconds (6 * 60 * 60, () => {
                check_for_updates (false);
                return true;
            });
        }

        private void setup_actions (Application app) {
            var add_app = new SimpleAction ("add-app", null);
            add_app.activate.connect (open_add_dialog);
            this.add_action (add_app);
            var settings_action = new SimpleAction ("settings", null);
            settings_action.activate.connect (show_settings);
            this.add_action (settings_action);
            var refresh = new SimpleAction ("refresh-library", null);
            refresh.activate.connect (refresh_apps);
            this.add_action (refresh);
            var open = new SimpleAction ("open-applications", null);
            open.activate.connect (() => System.open_directory (System.applications_dir ()));
            this.add_action (open);

            app.set_accels_for_action ("win.add-app", { "<Control>o" });
            app.set_accels_for_action ("win.refresh-library", { "<Control>r" });
            app.set_accels_for_action ("app.quit", { "<Control>q" });
        }

        private void setup_signals () {
            library.add_requested.connect (open_add_dialog);
            library.update_requested.connect (update_app);
            library.refresh_button.clicked.connect (refresh_apps);
            library.configure_requested.connect (open_config);
            library.delete_requested.connect (confirm_delete);
            library.launch_requested.connect (launch_app);

            settings_page.settings_changed.connect (save_settings);

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
                    toast ("Installation in progress. Please wait...");
                    return true;
                }
                if (settings.run_in_background && background_available) {
                    this.hide ();
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
                toast ("Installation in progress. Please wait...");
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
            retry_url = null;
            retry_update = null;
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
            var version = app.version;
            if ((version == null || version.strip () == "") && app.release_tag != null) {
                version = Forge.version_label (app.release_tag);
            }
            if (version != null && version.strip () != "") {
                meta += "  -  Version " + version;
            }
            if (app.source_url != null) {
                var source = Forge.repo_from_url (app.source_url);
                meta += "  -  From " + (source != null ? source.host : "a link");
            }
            ready.meta_label.label = meta;
            var target = Installer.target_path (app);
            var existing = Apps.find_by_path (target);
            var replacing = FileUtils.test (target, FileTest.EXISTS) || existing != null;
            var upgrading = false;
            if (existing != null) {
                if (app.release_tag != null && existing.release_tag != null) {
                    upgrading = app.release_tag != existing.release_tag;
                } else if (app.version != null && existing.version != null) {
                    upgrading = app.version != existing.version;
                }
            }
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
            retry_url = null;
            retry_update = null;
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

        private void show_done (Installed result, bool updated = false) {
            done.title_label.label = result.name + (updated ? " is up to date" : " is installed");
            done.subtitle_label.label = updated
                ? "The latest version is now installed."
                : "It should now appear in your app grid.";
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
            error_page.retry_button.visible = retry_path != null || retry_url != null || retry_update != null || retry_install;
            error_page.choose_button.visible = !opened_with_file;
            use_installer_size ();
            stack.visible_child_name = "error";
        }

        private void open_add_dialog () {
            if (installing_now) {
                toast ("Installation in progress. Please wait...");
                return;
            }
            if (add_dialog != null) {
                add_dialog.present ();
                return;
            }
            var dialog = new AddDialog (this);
            add_dialog = dialog;
            dialog.close_request.connect (() => {
                add_dialog = null;
                return false;
            });
            dialog.file_requested.connect (() => {
                var current = add_dialog;
                add_dialog = null;
                if (current != null) {
                    current.close ();
                }
                choose_file ();
            });
            dialog.link_requested.connect (() => {
                var current = add_dialog;
                add_dialog = null;
                if (current != null) {
                    current.close ();
                }
                open_url_dialog ();
            });
            dialog.present ();
        }

        private void open_url_dialog () {
            if (installing_now) {
                toast ("Installation in progress. Please wait...");
                return;
            }
            if (url_dialog != null) {
                url_dialog.present ();
                return;
            }
            var dialog = new UrlDialog (this);
            url_dialog = dialog;
            dialog.close_request.connect (() => {
                url_dialog = null;
                return false;
            });
            dialog.submitted.connect ((url) => {
                url_dialog = null;
                dialog.close ();
                begin_url_install (url);
            });
            dialog.present ();
        }

        private void begin_url_install (string url) {
            if (installing_now) {
                toast ("Installation in progress. Please wait...");
                return;
            }
            opened_with_file = true;
            inspection = null;
            installed = null;
            retry_path = null;
            retry_url = null;
            retry_update = null;
            retry_install = false;
            clear_pending_selection ();
            request_id += 1;
            var request = request_id;
            var repo = Forge.repo_from_url (url);
            if (repo == null) {
                begin_direct_download (url, request);
                return;
            }
            use_installer_size ();
            installing_page.reset ("Checking " + repo.path + "...",
                                   "Looking up the latest release on " + repo.host + ".");
            stack.visible_child_name = "installing";

            new Thread<void*> ("release", () => {
                ReleaseInfo? release = null;
                var assets = new GLib.GenericArray<ReleaseAsset> ();
                string? error = null;
                try {
                    release = Forge.latest_release (repo);
                    assets = Forge.appimage_assets (release);
                    if (assets.length == 0) {
                        throw new AppRollerError.FAILED ("The latest release doesn't include a raw AppImage asset.");
                    }
                } catch (AppRollerError e) {
                    error = e.message;
                } catch (Error e) {
                    error = e.message;
                }
                Idle.add (() => {
                    if (request != this.request_id) {
                        return false;
                    }
                    if (release == null || error != null) {
                        retry_url = url;
                        show_error ("Couldn't add that link", error != null ? error : "Unknown error");
                    } else if (assets.length > 1) {
                        pending_repo = release.repo != null ? release.repo : repo;
                        pending_release = release;
                        pending_update = null;
                        open_asset_dialog (assets, null,
                                           "This release includes multiple AppImage files. Choose the one to install.");
                    } else {
                        install_remote_asset (release.repo != null ? release.repo : repo, release, assets.get (0), url);
                    }
                    return false;
                });
                return null;
            });
        }

        private void begin_direct_download (string url, uint request) {
            use_installer_size ();
            installing_page.reset ("Downloading app...", "Fetching the app from the link.");
            stack.visible_child_name = "installing";
            retry_url = url;

            new Thread<void*> ("url", () => {
                AppImage? app = null;
                string? error = null;
                TempDir? download = null;
                try {
                    download = new TempDir ();
                    var path = Path.build_filename (download.path, Forge.file_name_from_url (url));
                    Forge.download (url, path);
                    if (!Installer.looks_like_appimage (path)) {
                        throw new AppRollerError.FAILED ("That link didn't point to an AppImage file.");
                    }
                    app = Installer.inspect (path);
                    app.download_scratch = download;
                    var tracking = Forge.repo_for_tracking (url);
                    app.source_url = tracking != null ? tracking.web_url : null;
                } catch (AppRollerError e) {
                    error = e.message;
                } catch (Error e) {
                    error = e.message;
                }
                Idle.add (() => {
                    if (request == this.request_id) {
                        if (app != null) {
                            show_ready (app);
                        } else {
                            retry_url = url;
                            retry_path = null;
                            retry_install = false;
                            show_error ("Couldn't add that link", error != null ? error : "Unknown error");
                        }
                    }
                    return false;
                });
                return null;
            });
        }

        private void install_remote_asset (ForgeRepo repo, ReleaseInfo release, ReleaseAsset asset, string retry_url_value) {
            request_id += 1;
            var request = request_id;
            retry_url = retry_url_value;
            retry_path = null;
            retry_update = null;
            retry_install = false;
            use_installer_size ();
            installing_page.reset ("Downloading " + asset.download_name () + "...",
                                   "Fetching the latest release from " + repo.host + ".");
            stack.visible_child_name = "installing";

            new Thread<void*> ("url-download", () => {
                AppImage? app = null;
                string? error = null;
                TempDir? download = null;
                try {
                    download = new TempDir ();
                    var path = Path.build_filename (download.path, asset.download_name ());
                    Forge.download (asset.url, path);
                    if (!Installer.looks_like_appimage (path)) {
                        throw new AppRollerError.FAILED ("That release asset isn't an AppImage.");
                    }
                    app = Installer.inspect (path);
                    app.download_scratch = download;
                    app.source_url = repo.web_url;
                    app.release_tag = release.tag;
                    app.asset_name = asset.name;
                } catch (AppRollerError e) {
                    error = e.message;
                } catch (Error e) {
                    error = e.message;
                }
                Idle.add (() => {
                    if (request == this.request_id) {
                        if (app != null) {
                            show_ready (app);
                        } else {
                            retry_url = retry_url_value;
                            retry_path = null;
                            retry_install = false;
                            show_error ("Couldn't add that link", error != null ? error : "Unknown error");
                        }
                    }
                    return false;
                });
                return null;
            });
        }

        private void open_asset_dialog (GLib.GenericArray<ReleaseAsset> assets, UpdateInfo? update, string description) {
            if (asset_dialog != null) {
                asset_dialog.present ();
                return;
            }
            var preferred = update != null ? Forge.find_asset_by_name (assets, update.app.asset_name) : null;
            var dialog = new AssetDialog (this, "Choose an AppImage", description, assets, preferred);
            asset_dialog = dialog;
            dialog.close_request.connect (() => {
                if (asset_dialog == dialog) {
                    asset_dialog = null;
                    clear_pending_selection ();
                    reset_to_library ();
                }
                return false;
            });
            dialog.chosen.connect ((asset) => {
                var current = asset_dialog;
                asset_dialog = null;
                if (current != null) {
                    current.close ();
                }
                if (pending_update != null) {
                    var chosen_update = pending_update;
                    clear_pending_selection ();
                    start_update (chosen_update, asset);
                } else if (pending_release != null && pending_repo != null) {
                    var chosen_release = pending_release;
                    var chosen_repo = pending_repo;
                    clear_pending_selection ();
                    install_remote_asset (chosen_repo, chosen_release, asset, chosen_repo.web_url);
                }
            });
            dialog.present ();
        }

        private void clear_pending_selection () {
            pending_repo = null;
            pending_release = null;
            pending_update = null;
        }

        private void check_for_updates (bool manual) {
            if (updates_checking) {
                if (manual) {
                    toast ("Already checking for updates...");
                }
                return;
            }
            var apps = Apps.list ();
            bool trackable = false;
            foreach (var app in apps) {
                if (app.source_url != null && Forge.repo_from_url (app.source_url) != null) {
                    trackable = true;
                    break;
                }
            }
            if (!trackable) {
                updates = new GLib.GenericArray<UpdateInfo> ();
                refresh_library ();
                if (manual) {
                    toast ("No apps with a tracked forge source to check.");
                }
                return;
            }

            updates_checking = true;
            if (manual) {
                toast ("Checking for updates...");
            }
            new Thread<void*> ("updates", () => {
                var found = new GLib.GenericArray<UpdateInfo> ();
                int failures = 0;
                foreach (var app in apps) {
                    if (app.source_url == null) {
                        continue;
                    }
                    var repo = Forge.repo_from_url (app.source_url);
                    if (repo == null) {
                        continue;
                    }
                    try {
                        var release = Forge.latest_release (repo);
                        var assets = Forge.appimage_assets (release);
                        if (assets.length == 0) {
                            continue;
                        }
                        var baseline = app.release_tag != null && app.release_tag.strip () != ""
                            ? app.release_tag : app.version;
                        if (!Forge.is_newer (release.tag, baseline)) {
                            continue;
                        }
                        var info = new UpdateInfo (app, assets);
                        info.tag = release.tag;
                        info.version = Forge.version_label (release.tag);
                        info.source_url = release.repo != null ? release.repo.web_url : repo.web_url;
                        info.provider = release.provider;
                        info.kind = release.repo != null ? release.repo.kind : repo.kind;
                        found.add (info);
                    } catch (AppRollerError e) {
                        failures += 1;
                    }
                }
                Idle.add (() => {
                    updates_checking = false;
                    updates = found;
                    refresh_library ();
                    if (found.length > 0 && settings.auto_update) {
                        update_all (found);
                    } else if (found.length > 0) {
                        toast (found.length == 1
                            ? "1 update available"
                            : found.length.to_string () + " updates available");
                    } else if (manual && failures > 0) {
                        toast ("Couldn't check some apps for updates.");
                    } else if (manual) {
                        toast ("Everything is up to date.");
                    }
                    return false;
                });
                return null;
            });
        }

        private void update_app (InstalledApp app) {
            if (auto_updating) {
                toast ("Updates are already being installed.");
                return;
            }
            if (installing_now) {
                toast ("Installation in progress. Please wait...");
                return;
            }
            UpdateInfo? found = null;
            foreach (var candidate in updates) {
                if (candidate.app.app_path == app.app_path) {
                    found = candidate;
                    break;
                }
            }
            if (found == null) {
                toast ("No update available for " + app.name + ".");
                return;
            }
            begin_update (found);
        }

        private void update_all (GLib.GenericArray<UpdateInfo> items) {
            if (auto_updating || installing_now) {
                return;
            }
            auto_updating = true;
            var pending = new GLib.GenericArray<UpdateInfo> ();
            foreach (var update in items) {
                pending.add (update);
            }

            new Thread<void*> ("update-all", () => {
                var failed = new GLib.GenericArray<UpdateInfo> ();
                int count = 0;
                string? error = null;
                foreach (var update in pending) {
                    var asset = Forge.find_asset_by_name (update.assets, update.app.asset_name);
                    if (asset == null) {
                        asset = Forge.recommended_asset (update.assets);
                    }
                    if (asset == null) {
                        failed.add (update);
                        continue;
                    }
                    TempDir? download = null;
                    try {
                        download = new TempDir ();
                        var path = Path.build_filename (download.path, asset.download_name ());
                        Forge.download (asset.url, path);
                        var appimage = Installer.inspect (path);
                        appimage.download_scratch = download;
                        appimage.source_url = update.source_url;
                        appimage.release_tag = update.tag;
                        appimage.asset_name = asset.name;
                        Installer.install (appimage);
                        count += 1;
                    } catch (AppRollerError e) {
                        failed.add (update);
                        error = e.message;
                    } catch (Error e) {
                        failed.add (update);
                        error = e.message;
                    }
                }
                Idle.add (() => {
                    auto_updating = false;
                    updates = failed;
                    refresh_library ();
                    if (count > 0) {
                        toast (count == 1 ? "Updated 1 app" : "Updated " + count.to_string () + " apps");
                    }
                    if (failed.length > 0) {
                        toast ("Couldn't update " + failed.length.to_string () + " apps" + (error != null ? ": " + error : ""));
                    }
                    return false;
                });
                return null;
            });
        }

        private void begin_update (UpdateInfo update) {
            if (auto_updating) {
                toast ("Updates are already being installed.");
                return;
            }
            if (installing_now) {
                toast ("Installation in progress. Please wait...");
                return;
            }
            var assets = update.assets;
            if (assets.length == 0) {
                toast ("That release doesn't include an AppImage.");
                return;
            }
            if (assets.length == 1) {
                start_update (update, assets.get (0));
                return;
            }
            pending_repo = null;
            pending_release = null;
            pending_update = update;
            open_asset_dialog (assets, update,
                               "This release includes multiple AppImage files. Choose the one to update with.");
        }

        private void start_update (UpdateInfo update, ReleaseAsset asset) {
            if (installing_now) {
                toast ("Installation in progress. Please wait...");
                return;
            }
            installing_now = true;
            inspection = null;
            installed = null;
            retry_path = null;
            retry_url = null;
            retry_update = null;
            retry_install = false;
            request_id += 1;
            var request = request_id;
            use_installer_size ();
            var provider = update.provider != "" ? update.provider : "the forge";
            installing_page.reset ("Updating " + update.app.name + "...",
                                   "Downloading version " + update.version + " from " + provider + ".");
            stack.visible_child_name = "installing";

            new Thread<void*> ("update", () => {
                Installed? result = null;
                string? error = null;
                TempDir? download = null;
                try {
                    download = new TempDir ();
                    var path = Path.build_filename (download.path, asset.download_name ());
                    Forge.download (asset.url, path);
                    var appimage = Installer.inspect (path);
                    appimage.download_scratch = download;
                    appimage.source_url = update.source_url;
                    appimage.release_tag = update.tag;
                    appimage.asset_name = asset.name;
                    result = Installer.install (appimage);
                } catch (AppRollerError e) {
                    error = e.message;
                } catch (Error e) {
                    error = e.message;
                }
                Idle.add (() => {
                    if (request != this.request_id) {
                        return false;
                    }
                    installing_now = false;
                    if (result != null) {
                        installed = result;
                        retry_update = null;
                        var remaining = new GLib.GenericArray<UpdateInfo> ();
                        foreach (var candidate in updates) {
                            if (candidate.app.app_path != update.app.app_path) {
                                remaining.add (candidate);
                            }
                        }
                        updates = remaining;
                        refresh_library ();
                        show_done (result, true);
                    } else {
                        retry_update = update;
                        show_error ("Update failed", error != null ? error : "Unknown error");
                    }
                    return false;
                });
                return null;
            });
        }

        private void refresh_library () {
            library.refresh (Apps.list (), updates);
        }

        private void refresh_apps () {
            refresh_library ();
            check_for_updates (true);
        }

        private void show_settings () {
            stack.visible_child_name = "settings";
            back_button.visible = true;
            use_library_size ();
        }

        private void save_settings (Settings settings) {
            try {
                settings.save ();
            } catch (FileError e) {
                toast (e.message);
            }
            if (settings.auto_update) {
                if (updates.length > 0) {
                    update_all (updates);
                } else {
                    check_for_updates (false);
                }
            }
        }

        private void reset_to_library () {
            request_id += 1;
            opened_with_file = false;
            inspection = null;
            installed = null;
            retry_path = null;
            retry_url = null;
            retry_update = null;
            retry_install = false;
            clear_pending_selection ();
            back_button.visible = false;
            refresh_library ();
            use_library_size ();
            stack.visible_child_name = "library";
        }

        private void retry () {
            if (retry_install && inspection != null) {
                begin_install ();
            } else if (retry_update != null) {
                var update = retry_update;
                retry_update = null;
                begin_update (update);
            } else if (retry_url != null) {
                var url = retry_url;
                begin_url_install (url);
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
                toast (e.message);
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
                toast (e.message);
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
                    var source_changed = (config.source_url != null ? config.source_url.strip () : "") !=
                                         (app.source_url != null ? app.source_url : "");
                    Apps.save_config (app, config);
                    toast ("Saved " + config.name);
                    refresh_library ();
                    dialog.close ();
                    if (source_changed && config.source_url != null && config.source_url.strip () != "") {
                        check_for_updates (false);
                    }
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
