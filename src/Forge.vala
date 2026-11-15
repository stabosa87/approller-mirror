namespace AppRoller {
    public enum ForgeKind {
        GITHUB,
        GITLAB,
        GITEA,
        FORGEJO,
        UNKNOWN
    }

    public class ForgeRepo : GLib.Object {
        public ForgeKind kind = ForgeKind.UNKNOWN;
        public string scheme = "https";
        public string host = "";
        public string path = "";
        public string origin = "";
        public string web_url = "";
    }

    public class ReleaseAsset : GLib.Object {
        public string name = "";
        public string url = "";
        public int64 size = 0;

        public string download_name () {
            var url_name = Forge.file_name_from_url (url);
            var trimmed = name.strip ();
            if (trimmed != "") {
                var file_name = Path.get_basename (trimmed);
                if (file_name.down ().has_suffix (".appimage")) {
                    return file_name;
                }
            }
            if (url_name != "" && url_name != "download.AppImage") {
                return url_name;
            }
            if (trimmed != "") {
                return Path.get_basename (trimmed);
            }
            return "app.AppImage";
        }
    }

    public class ReleaseInfo : GLib.Object {
        public ForgeRepo? repo = null;
        public string provider = "";
        public string tag = "";
        public string? title = null;
        public string? page_url = null;
        public bool prerelease = false;
        public GLib.List<ReleaseAsset> assets;

        public ReleaseInfo () {
            assets = new GLib.List<ReleaseAsset> ();
        }
    }

    public class UpdateInfo : GLib.Object {
        public InstalledApp app;
        public GLib.GenericArray<ReleaseAsset> assets;
        public string tag = "";
        public string version = "";
        public string source_url = "";
        public string provider = "";
        public ForgeKind kind = ForgeKind.UNKNOWN;

        public UpdateInfo (InstalledApp app, GLib.GenericArray<ReleaseAsset> assets) {
            this.app = app;
            this.assets = assets;
        }
    }

    public class Forge : GLib.Object {
        private static string? arch_cache = null;

        public static ForgeRepo? repo_from_url (string url) {
            return parse_repo (url, true);
        }

        public static ForgeRepo? repo_for_tracking (string url) {
            var repo = parse_repo (url, false);
            if (repo == null) {
                return null;
            }
            if (repo.kind == ForgeKind.GITHUB) {
                return repo;
            }
            var lower = url.down ();
            if (lower.contains ("/-/releases") || lower.contains ("/releases/download/") ||
                lower.contains ("/releases/tag/")) {
                return repo;
            }
            return null;
        }

        private static ForgeRepo? parse_repo (string url, bool reject_asset) {
            var text = url.strip ();
            if (text == "") {
                return null;
            }

            var lower = text.down ();
            int fragment = lower.index_of ("#");
            if (fragment >= 0) {
                text = text.substring (0, fragment);
                lower = text.down ();
            }
            int query = lower.index_of ("?");
            if (query >= 0) {
                text = text.substring (0, query);
                lower = text.down ();
            }
            if (reject_asset && (lower.has_suffix (".appimage") || lower.has_suffix (".appimage.zsync"))) {
                return null;
            }

            var rest = text;
            var scheme = "https";
            string? host = null;
            var path = "";

            int scheme_index = rest.index_of ("://");
            if (scheme_index >= 0) {
                scheme = rest.substring (0, scheme_index).down ();
                rest = rest.substring (scheme_index + 3);
                int slash = rest.index_of ("/");
                if (slash < 0) {
                    return null;
                }
                host = rest.substring (0, slash);
                path = rest.substring (slash + 1);
            } else if (rest.down ().has_prefix ("git@")) {
                int at = rest.index_of ("@");
                int colon = rest.index_of (":");
                if (at < 0 || colon <= at) {
                    return null;
                }
                host = rest.substring (at + 1, colon);
                path = rest.substring (colon + 1);
            } else {
                int slash = rest.index_of ("/");
                if (slash < 0) {
                    return null;
                }
                host = rest.substring (0, slash);
                path = rest.substring (slash + 1);
            }

            if (host == null) {
                return null;
            }
            var normalized_host = host.down ();
            int at = normalized_host.index_of ("@");
            if (at >= 0) {
                normalized_host = normalized_host.substring (at + 1);
            }
            if (normalized_host.has_prefix ("www.")) {
                normalized_host = normalized_host.substring (4);
            }

            var path_text = path.strip ();
            while (path_text.has_prefix ("/")) {
                path_text = path_text.substring (1);
            }
            while (path_text.has_suffix ("/")) {
                path_text = path_text.substring (0, path_text.length - 1);
            }
            if (normalized_host == "" || path_text == "") {
                return null;
            }
            if (path_text.has_suffix (".git")) {
                path_text = path_text.substring (0, path_text.length - 4);
            }

            var kind = normalized_host == "github.com" ? ForgeKind.GITHUB : ForgeKind.UNKNOWN;
            int marker = path_text.index_of ("/-/");
            if (marker >= 0) {
                path_text = path_text.substring (0, marker);
            }
            int release_marker = path_text.index_of ("/releases/download/");
            if (release_marker < 0) {
                release_marker = path_text.index_of ("/releases/tag/");
            }
            if (release_marker >= 0) {
                path_text = path_text.substring (0, release_marker);
            }

            if (kind == ForgeKind.GITHUB) {
                var parts = path_text.split ("/");
                if (parts.length < 2) {
                    return null;
                }
                var owner = parts[0].strip ();
                var name = parts[1].strip ();
                if (name.has_suffix (".git")) {
                    name = name.substring (0, name.length - 4);
                }
                if (!valid_name (owner) || !valid_name (name)) {
                    return null;
                }
                path_text = owner + "/" + name;
            } else {
                path_text = strip_path_suffixes (path_text);
                var parts = path_text.split ("/");
                if (parts.length < 2) {
                    return null;
                }
                foreach (var part in parts) {
                    if (!valid_name (part.strip ())) {
                        return null;
                    }
                }
            }

            var repo = new ForgeRepo ();
            repo.kind = kind;
            repo.scheme = scheme;
            repo.host = normalized_host;
            repo.path = path_text;
            repo.origin = scheme + "://" + normalized_host;
            repo.web_url = repo.origin + "/" + path_text;
            return repo;
        }

        private static ForgeKind[] probe_order () {
            return { ForgeKind.GITEA, ForgeKind.GITLAB, ForgeKind.GITHUB };
        }

        private static string strip_path_suffixes (string path) {
            var result = path;
            while (true) {
                int slash = result.last_index_of ("/");
                if (slash < 0) {
                    break;
                }
                var last = result.substring (slash + 1).down ();
                bool drop = last == "releases" || last == "tags" || last == "tree" ||
                            last == "commits" || last == "issues" || last == "pulls" ||
                            last == "merge_requests" || last == "wiki" || last == "archive";
                if (!drop || result.substring (0, slash).index_of ("/") < 0) {
                    break;
                }
                result = result.substring (0, slash);
            }
            return result;
        }

        private static bool valid_name (string value) {
            if (value == "" || value == "." || value == "..") {
                return false;
            }
            for (int i = 0; i < value.length; i++) {
                var c = value[i];
                if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
                      (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '+')) {
                    return false;
                }
            }
            return true;
        }

        public static ReleaseInfo latest_release (ForgeRepo repo) throws AppRollerError {
            if (repo.kind == ForgeKind.GITHUB) {
                return fetch_github (repo);
            }
            if (repo.kind == ForgeKind.GITLAB) {
                return fetch_gitlab (repo);
            }
            if (repo.kind == ForgeKind.GITEA || repo.kind == ForgeKind.FORGEJO) {
                return fetch_gitea (repo);
            }

            string? first_error = null;
            foreach (var kind in probe_order ()) {
                var attempt = repo_with_path (repo, kind == ForgeKind.GITLAB ? repo.path : short_path (repo.path));
                attempt.kind = kind;
                try {
                    switch (kind) {
                        case ForgeKind.GITEA:
                        case ForgeKind.FORGEJO:
                            var release = fetch_gitea (attempt);
                            refine_gitea (attempt, release);
                            return release;
                        case ForgeKind.GITLAB:
                            return fetch_gitlab (attempt);
                        case ForgeKind.GITHUB:
                            return fetch_github (attempt);
                        default:
                            break;
                    }
                } catch (AppRollerError e) {
                    if (first_error == null) {
                        first_error = e.message;
                    }
                }
            }
            throw new AppRollerError.FAILED (first_error != null
                ? first_error
                : "Couldn't find a release for " + repo.path + " on " + repo.host + ".");
        }

        private static ForgeRepo repo_with_path (ForgeRepo repo, string path) {
            var copy = new ForgeRepo ();
            copy.scheme = repo.scheme;
            copy.host = repo.host;
            copy.path = path;
            copy.origin = repo.origin;
            copy.web_url = repo.origin + "/" + path;
            return copy;
        }

        private static string short_path (string path) {
            var parts = path.split ("/");
            if (parts.length <= 2) {
                return path;
            }
            return parts[0] + "/" + parts[1];
        }

        private static void refine_gitea (ForgeRepo repo, ReleaseInfo release) {
            if (gitea_is_forgejo (repo)) {
                repo.kind = ForgeKind.FORGEJO;
                release.provider = "Forgejo";
            } else {
                repo.kind = ForgeKind.GITEA;
                release.provider = "Gitea";
            }
        }

        private static bool gitea_is_forgejo (ForgeRepo repo) {
            try {
                int status = 0;
                var body = http_get (repo.origin + "/api/v1/version", "application/json", out status);
                return status == 200 && body.down ().contains ("forgejo");
            } catch (AppRollerError e) {
                return false;
            }
        }

        private static string github_api (ForgeRepo repo) {
            if (repo.host == "github.com") {
                return "https://api.github.com";
            }
            return repo.origin + "/api/v3";
        }

        private static ReleaseInfo fetch_github (ForgeRepo repo) throws AppRollerError {
            var url = github_api (repo) + "/repos/" + repo.path + "/releases/latest";
            int status = 0;
            var body = http_get (url, "application/vnd.github+json", out status);
            if (status == 404) {
                throw new AppRollerError.FAILED ("No published release found for " + repo.path + " on GitHub.");
            }
            if (status == 403 || status == 429) {
                throw new AppRollerError.FAILED ("GitHub is rate limiting requests. Try again later.");
            }
            if (status != 200) {
                throw new AppRollerError.FAILED ("GitHub returned HTTP " + status.to_string () + " for " + repo.path + ".");
            }
            return parse_github (body, repo);
        }

        private static ReleaseInfo fetch_gitlab (ForgeRepo repo) throws AppRollerError {
            var project = Uri.escape_string (repo.path, null, false);
            var url = repo.origin + "/api/v4/projects/" + project + "/releases?per_page=1";
            int status = 0;
            var body = http_get (url, "application/json", out status);
            if (status == 404) {
                throw new AppRollerError.FAILED ("No project or release found for " + repo.path + " on GitLab.");
            }
            if (status == 401 || status == 403) {
                throw new AppRollerError.FAILED ("GitLab refused access to " + repo.path + ". The project may be private.");
            }
            if (status != 200) {
                throw new AppRollerError.FAILED ("GitLab returned HTTP " + status.to_string () + " for " + repo.path + ".");
            }
            return parse_gitlab (body, repo);
        }

        private static ReleaseInfo fetch_gitea (ForgeRepo repo) throws AppRollerError {
            var url = repo.origin + "/api/v1/repos/" + repo.path +
                      "/releases?limit=1&draft=false&pre-release=false";
            int status = 0;
            var body = http_get (url, "application/json", out status);
            if (status == 404) {
                throw new AppRollerError.FAILED ("No repository or release found for " + repo.path + " on " + repo.host + ".");
            }
            if (status == 401 || status == 403) {
                throw new AppRollerError.FAILED (repo.host + " refused access to " + repo.path + ". The repository may be private.");
            }
            if (status != 200) {
                throw new AppRollerError.FAILED (repo.host + " returned HTTP " + status.to_string () + " for " + repo.path + ".");
            }
            return parse_gitea (body, repo);
        }

        private static ReleaseInfo parse_github (string body, ForgeRepo repo) throws AppRollerError {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (body);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
                    throw new AppRollerError.FAILED ("GitHub returned an unexpected response.");
                }
                var obj = root.get_object ();
                var release = new ReleaseInfo ();
                release.repo = repo;
                release.provider = "GitHub";
                var tag = json_string (obj, "tag_name");
                release.tag = tag != null ? tag : "latest";
                release.title = json_string (obj, "name");
                release.page_url = json_string (obj, "html_url");
                release.prerelease = json_bool (obj, "prerelease");

                var assets_node = json_array (obj, "assets");
                if (assets_node != null) {
                    for (uint i = 0; i < assets_node.get_length (); i++) {
                        var asset_obj = assets_node.get_object_element (i);
                        if (asset_obj == null) {
                            continue;
                        }
                        var name = json_string (asset_obj, "name");
                        var download = json_string (asset_obj, "browser_download_url");
                        if (download == null || download.strip () == "") {
                            continue;
                        }
                        var asset = new ReleaseAsset ();
                        asset.name = name != null && name.strip () != "" ? name : file_name_from_url (download);
                        asset.url = download;
                        asset.size = json_int (asset_obj, "size");
                        release.assets.append (asset);
                    }
                }
                return release;
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }

        private static ReleaseInfo parse_gitlab (string body, ForgeRepo repo) throws AppRollerError {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (body);
                var root = parser.get_root ();
                if (root == null) {
                    throw new AppRollerError.FAILED ("GitLab returned an unexpected response.");
                }
                Json.Object? obj = null;
                if (root.get_node_type () == Json.NodeType.ARRAY) {
                    var array = root.get_array ();
                    if (array.get_length () == 0) {
                        throw new AppRollerError.FAILED ("No published release found for " + repo.path + " on GitLab.");
                    }
                    obj = array.get_object_element (0);
                } else if (root.get_node_type () == Json.NodeType.OBJECT) {
                    obj = root.get_object ();
                }
                var release_obj = obj;
                if (release_obj == null) {
                    throw new AppRollerError.FAILED ("GitLab returned an unexpected response.");
                }

                var release = new ReleaseInfo ();
                release.repo = repo;
                release.provider = "GitLab";
                var tag = json_string (release_obj, "tag_name");
                release.tag = tag != null ? tag : "latest";
                release.title = json_string (release_obj, "name");
                release.prerelease = json_bool (release_obj, "upcoming_release");

                var links_obj = json_object (release_obj, "_links");
                if (links_obj != null) {
                    release.page_url = json_string (links_obj, "self");
                } else {
                    release.page_url = repo.web_url + "/-/releases/" + release.tag;
                }

                var assets_obj = json_object (release_obj, "assets");
                var links_node = assets_obj != null ? json_array (assets_obj, "links") : null;
                if (links_node != null) {
                    for (uint i = 0; i < links_node.get_length (); i++) {
                        var link_obj = links_node.get_object_element (i);
                        if (link_obj == null) {
                            continue;
                        }
                        var name = json_string (link_obj, "name");
                        var url = json_string (link_obj, "direct_asset_url");
                        if (url == null || url.strip () == "") {
                            url = json_string (link_obj, "url");
                        }
                        if (url == null || url.strip () == "") {
                            continue;
                        }
                        var asset = new ReleaseAsset ();
                        asset.name = name != null && name.strip () != "" ? name : file_name_from_url (url);
                        asset.url = url;
                        release.assets.append (asset);
                    }
                }
                return release;
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED ("Couldn't read GitLab's response: " + e.message);
            }
        }

        private static ReleaseInfo parse_gitea (string body, ForgeRepo repo) throws AppRollerError {
            try {
                var parser = new Json.Parser ();
                parser.load_from_data (body);
                var root = parser.get_root ();
                if (root == null) {
                    throw new AppRollerError.FAILED (repo.host + " returned an unexpected response.");
                }
                Json.Object? obj = null;
                if (root.get_node_type () == Json.NodeType.ARRAY) {
                    var array = root.get_array ();
                    if (array.get_length () == 0) {
                        throw new AppRollerError.FAILED ("No published release found for " + repo.path + " on " + repo.host + ".");
                    }
                    obj = array.get_object_element (0);
                } else if (root.get_node_type () == Json.NodeType.OBJECT) {
                    obj = root.get_object ();
                }
                var release_obj = obj;
                if (release_obj == null) {
                    throw new AppRollerError.FAILED (repo.host + " returned an unexpected response.");
                }

                var release = new ReleaseInfo ();
                release.repo = repo;
                release.provider = repo.kind == ForgeKind.FORGEJO ? "Forgejo" : "Gitea";
                var tag = json_string (release_obj, "tag_name");
                release.tag = tag != null ? tag : "latest";
                release.title = json_string (release_obj, "name");
                release.page_url = json_string (release_obj, "html_url");
                release.prerelease = json_bool (release_obj, "prerelease");

                var assets_node = json_array (release_obj, "assets");
                if (assets_node != null) {
                    for (uint i = 0; i < assets_node.get_length (); i++) {
                        var asset_obj = assets_node.get_object_element (i);
                        if (asset_obj == null) {
                            continue;
                        }
                        var name = json_string (asset_obj, "name");
                        var download = json_string (asset_obj, "browser_download_url");
                        if (download == null || download.strip () == "") {
                            continue;
                        }
                        var asset = new ReleaseAsset ();
                        asset.name = name != null && name.strip () != "" ? name : file_name_from_url (download);
                        asset.url = download;
                        asset.size = json_int (asset_obj, "size");
                        release.assets.append (asset);
                    }
                }
                return release;
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED ("Couldn't read " + repo.host + "'s response: " + e.message);
            }
        }

        public static GLib.GenericArray<ReleaseAsset> appimage_assets (ReleaseInfo release) {
            var result = new GLib.GenericArray<ReleaseAsset> ();
            foreach (var asset in release.assets) {
                var name = asset.name.strip ().down ();
                var url = strip_query (asset.url).down ();
                if (name.has_suffix (".appimage.zsync") || url.has_suffix (".appimage.zsync")) {
                    continue;
                }
                if (!name.has_suffix (".appimage") && !url.has_suffix (".appimage")) {
                    continue;
                }
                if (asset.name.strip () == "") {
                    asset.name = file_name_from_url (asset.url);
                }
                result.add (asset);
            }
            return result;
        }

        public static ReleaseAsset? recommended_asset (GLib.GenericArray<ReleaseAsset> assets) {
            ReleaseAsset? best = null;
            int best_score = -1000;
            var arch = host_arch ();
            bool wants_arm = arch.contains ("aarch64") || arch.contains ("arm64") || arch.contains ("armv");
            foreach (var asset in assets) {
                int score = asset_score (asset, wants_arm);
                if (score > best_score) {
                    best_score = score;
                    best = asset;
                }
            }
            return best;
        }

        public static ReleaseAsset? find_asset_by_name (GLib.GenericArray<ReleaseAsset> assets, string? name) {
            if (name == null || name.strip () == "") {
                return null;
            }
            var wanted = name.strip ().down ();
            foreach (var asset in assets) {
                if (asset.name.strip ().down () == wanted) {
                    return asset;
                }
                if (asset.download_name ().down () == wanted) {
                    return asset;
                }
            }
            return null;
        }

        public static string asset_arch_label (ReleaseAsset asset) {
            var lower = (asset.name + " " + asset.url).down ();
            if (lower.contains ("aarch64") || lower.contains ("arm64") ||
                lower.contains ("armv7") || lower.contains ("armhf") ||
                lower.contains ("armel") || lower.contains ("arm32")) {
                return "ARM";
            }
            if (lower.contains ("x86_64") || lower.contains ("x86-64") ||
                lower.contains ("amd64") || lower.contains ("x64")) {
                return "x86_64";
            }
            return "Any architecture";
        }

        private static int asset_score (ReleaseAsset asset, bool wants_arm) {
            var lower = (asset.name + " " + asset.url).down ();
            bool arm_asset = lower.contains ("aarch64") || lower.contains ("arm64") ||
                             lower.contains ("armv7") || lower.contains ("armhf") ||
                             lower.contains ("armel") || lower.contains ("arm32");
            bool x86_asset = lower.contains ("x86_64") || lower.contains ("x86-64") ||
                             lower.contains ("amd64") || lower.contains ("x64");
            int score = 0;
            if (wants_arm) {
                if (arm_asset) {
                    score += 20;
                }
                if (x86_asset) {
                    score -= 20;
                }
            } else {
                if (x86_asset) {
                    score += 20;
                }
                if (arm_asset) {
                    score -= 20;
                }
            }
            if (lower.contains ("universal")) {
                score += 5;
            }
            if (lower.contains ("debug")) {
                score -= 10;
            }
            if (lower.contains ("test")) {
                score -= 5;
            }
            return score;
        }

        public static void download (string url, string path) throws AppRollerError {
            int status = 0;
            var data = http_get_bytes (url, "application/octet-stream", out status);
            if (status < 200 || status >= 300) {
                throw new AppRollerError.FAILED ("The download failed (HTTP " + status.to_string () + ").");
            }
            if (data.length == 0) {
                throw new AppRollerError.FAILED ("The download was empty.");
            }
            try {
                FileUtils.set_data (path, data);
            } catch (FileError e) {
                throw new AppRollerError.FAILED (e.message);
            }
        }

        private static string http_get (string url, string accept, out int status) throws AppRollerError {
            var data = http_get_bytes (url, accept, out status);
            int length = data.length;
            uint8[] text = new uint8[length + 1];
            if (length > 0) {
                Memory.copy (text, data, (size_t) length);
            }
            text[length] = 0;
            return (string) text;
        }

        private static uint8[] http_get_bytes (string url, string accept, out int status) throws AppRollerError {
            status = 0;
            try {
                var session = new Soup.Session ();
                session.user_agent = "AppRoller/" + VERSION;
                session.timeout = 60;
                var message = new Soup.Message ("GET", url);
                message.request_headers.append ("Accept", accept);
                var bytes = session.send_and_read (message, null);
                status = (int) message.status_code;
                if (bytes == null) {
                    throw new AppRollerError.FAILED ("The server returned an empty response.");
                }
                return copy_bytes (bytes);
            } catch (AppRollerError e) {
                throw e;
            } catch (Error e) {
                throw new AppRollerError.FAILED ("Couldn't reach the server. Check your internet connection. " + e.message);
            }
        }

        private static uint8[] copy_bytes (GLib.Bytes bytes) {
            int size = (int) bytes.get_size ();
            uint8[] data = new uint8[size];
            if (size > 0) {
                Memory.copy (data, bytes.get_data (), (size_t) size);
            }
            return data;
        }

        private static Json.Object? json_object (Json.Object obj, string member) {
            if (!obj.has_member (member)) {
                return null;
            }
            var node = obj.get_member (member);
            if (node == null || node.get_node_type () != Json.NodeType.OBJECT) {
                return null;
            }
            return node.get_object ();
        }

        private static Json.Array? json_array (Json.Object obj, string member) {
            if (!obj.has_member (member)) {
                return null;
            }
            var node = obj.get_member (member);
            if (node == null || node.get_node_type () != Json.NodeType.ARRAY) {
                return null;
            }
            return node.get_array ();
        }

        private static string? json_string (Json.Object obj, string member) {
            if (!obj.has_member (member)) {
                return null;
            }
            var node = obj.get_member (member);
            if (node == null || node.get_node_type () != Json.NodeType.VALUE) {
                return null;
            }
            if (node.get_value_type () != typeof (string)) {
                return null;
            }
            return node.get_string ();
        }

        private static bool json_bool (Json.Object obj, string member) {
            if (!obj.has_member (member)) {
                return false;
            }
            var node = obj.get_member (member);
            if (node == null || node.get_value_type () != typeof (bool)) {
                return false;
            }
            return node.get_boolean ();
        }

        private static int64 json_int (Json.Object obj, string member) {
            if (!obj.has_member (member)) {
                return 0;
            }
            var node = obj.get_member (member);
            if (node == null || node.get_value_type () == typeof (string)) {
                return 0;
            }
            return node.get_int ();
        }

        public static string file_name_from_url (string url) {
            var value = strip_query (url);
            var name = Path.get_basename (value);
            if (name == "" || name == "/" || name == ".") {
                return "download.AppImage";
            }
            return name;
        }

        private static string strip_query (string url) {
            var value = url;
            int query = value.index_of ("?");
            if (query >= 0) {
                value = value.substring (0, query);
            }
            int fragment = value.index_of ("#");
            if (fragment >= 0) {
                value = value.substring (0, fragment);
            }
            return value;
        }

        public static string version_label (string tag) {
            var text = tag.strip ();
            if (text.length > 1 && (text[0] == 'v' || text[0] == 'V') && is_digit (text[1])) {
                return text.substring (1);
            }
            return text;
        }

        public static bool is_newer (string remote, string? current) {
            if (current == null || current.strip () == "") {
                return true;
            }
            var remote_text = remote.strip ();
            var current_text = current.strip ();
            if (remote_text == current_text) {
                return false;
            }

            int cmp = compare_core (version_core (remote_text), version_core (current_text));
            if (cmp != 0) {
                return cmp > 0;
            }

            var remote_pre = version_prerelease (remote_text);
            var current_pre = version_prerelease (current_text);
            if (remote_pre == current_pre) {
                return false;
            }
            if (remote_pre == null) {
                return true;
            }
            if (current_pre == null) {
                return false;
            }
            return remote_pre.collate (current_pre) > 0;
        }

        private static string normalized_version (string value) {
            var text = value.strip ().down ();
            if (text.length > 1 && text[0] == 'v' && is_digit (text[1])) {
                text = text.substring (1);
            }
            int plus = text.index_of ("+");
            if (plus >= 0) {
                text = text.substring (0, plus);
            }
            int digit = first_digit (text);
            if (digit > 0) {
                text = text.substring (digit);
            }
            return text;
        }

        private static string version_core (string value) {
            var text = normalized_version (value);
            int dash = text.index_of ("-");
            if (dash >= 0) {
                text = text.substring (0, dash);
            }
            int end = text.length;
            while (end > 0 && !is_digit (text[end - 1]) && text[end - 1] != '.') {
                end -= 1;
            }
            if (end > 0 && end < text.length) {
                text = text.substring (0, end);
            }
            while (text.has_suffix (".")) {
                text = text.substring (0, text.length - 1);
            }
            return text;
        }

        private static string? version_prerelease (string value) {
            var text = normalized_version (value);
            int dash = text.index_of ("-");
            if (dash >= 0 && dash + 1 < text.length) {
                return text.substring (dash + 1);
            }
            return null;
        }

        private static int compare_core (string a, string b) {
            var left_parts = a.split (".");
            var right_parts = b.split (".");
            var count = int.max (left_parts.length, right_parts.length);
            for (int i = 0; i < count; i++) {
                var left = i < left_parts.length ? left_parts[i] : "0";
                var right = i < right_parts.length ? right_parts[i] : "0";
                var left_number = leading_number (left);
                var right_number = leading_number (right);
                if (left_number != right_number) {
                    return left_number < right_number ? -1 : 1;
                }
                var left_rest = left.substring (leading_digit_count (left));
                var right_rest = right.substring (leading_digit_count (right));
                if (left_rest != right_rest) {
                    if (left_rest == "") {
                        return 1;
                    }
                    if (right_rest == "") {
                        return -1;
                    }
                    return left_rest.collate (right_rest) < 0 ? -1 : 1;
                }
            }
            return 0;
        }

        private static int64 leading_number (string value) {
            int64 result = 0;
            int digits = 0;
            for (int i = 0; i < value.length && digits < 18; i++) {
                var c = value[i];
                if (!is_digit (c)) {
                    break;
                }
                result = result * 10 + (int64) (c - '0');
                digits += 1;
            }
            return result;
        }

        private static int leading_digit_count (string value) {
            int count = 0;
            for (int i = 0; i < value.length; i++) {
                if (!is_digit (value[i])) {
                    break;
                }
                count += 1;
            }
            return count;
        }

        private static int first_digit (string value) {
            for (int i = 0; i < value.length; i++) {
                if (is_digit (value[i])) {
                    return i;
                }
            }
            return -1;
        }

        private static bool is_digit (char c) {
            return c >= '0' && c <= '9';
        }

        private static string host_arch () {
            if (arch_cache != null) {
                return arch_cache;
            }
            var arch = "x86_64";
            try {
                var process = new Subprocess (SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE, "uname", "-m");
                string? output = null;
                process.communicate_utf8 (null, null, out output, null);
                if (output != null && output.strip () != "") {
                    arch = output.strip ().down ();
                }
            } catch (Error e) {
            }
            arch_cache = arch;
            return arch;
        }
    }
}
