#!/bin/sh
set -eu

# Install the Cix Project website on a Debian VM.
# Run as root: ./deploy/install-vm.sh --domain=cixproject.org

REPO_URL="https://github.com/The-Cix-Project/the-cix-project-website.git"
BRANCH="main"
DOMAIN=""
REPO_DIR="/srv/the-cix-project-website.git"
SITE_DIR="/srv/the-cix-project-site"
UPDATE_SCRIPT="/usr/local/sbin/the-cix-project-website-update"
SERVICE_FILE="/etc/systemd/system/the-cix-project-website-update.service"
TIMER_FILE="/etc/systemd/system/the-cix-project-website-update.timer"
CADDYFILE="/etc/caddy/Caddyfile"
CADDY_SITES_DIR="/etc/caddy/sites-enabled"
CIX_CADDYFILE="$CADDY_SITES_DIR/the-cix-project-website.caddy"

usage() { echo "Usage: install-vm.sh --domain=cixproject.org [--branch=main]" >&2; }
for arg in "$@"; do
    case "$arg" in
        --domain=*) DOMAIN=${arg#--domain=} ;;
        --branch=*) BRANCH=${arg#--branch=} ;;
        --repo-url=*) REPO_URL=${arg#--repo-url=} ;;
        --help|-h) usage; exit 0 ;;
        *) echo "install-vm.sh: unknown option: $arg" >&2; usage; exit 2 ;;
    esac
done
[ "$(id -u)" -eq 0 ] || { echo "install-vm.sh: run as root" >&2; exit 1; }
[ -n "$DOMAIN" ] || { echo "install-vm.sh: --domain is required" >&2; usage; exit 2; }
case "$DOMAIN" in *[!A-Za-z0-9.-]*|.*|*.) echo "install-vm.sh: invalid hostname" >&2; exit 2 ;; esac
command -v apt-get >/dev/null 2>&1 || { echo "install-vm.sh: Debian apt-get is required" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y git python3 ca-certificates curl gnupg debian-keyring debian-archive-keyring apt-transport-https
if ! command -v caddy >/dev/null 2>&1; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
    chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
    apt-get update
    apt-get install -y caddy
fi

install -d -m 0755 "$SITE_DIR/releases" "$CADDY_SITES_DIR"
if [ -d "$REPO_DIR" ]; then
    git --git-dir="$REPO_DIR" rev-parse --is-bare-repository >/dev/null 2>&1 || { echo "$REPO_DIR is not bare" >&2; exit 1; }
    git --git-dir="$REPO_DIR" fetch --quiet origin "$BRANCH:refs/heads/$BRANCH"
else
    git clone --bare "$REPO_URL" "$REPO_DIR"
    git --git-dir="$REPO_DIR" fetch --quiet origin "$BRANCH:refs/heads/$BRANCH"
fi

cat > "$UPDATE_SCRIPT" <<'EOF'
#!/bin/sh
set -eu
repo="__REPO_DIR__"
root="__SITE_DIR__"
branch="__BRANCH__"
git --git-dir="$repo" fetch --quiet origin "$branch:refs/heads/$branch"
commit=$(git --git-dir="$repo" rev-parse "refs/heads/$branch")
release="$root/releases/$commit"
if [ ! -d "$release" ]; then
    temporary="$root/releases/.$commit.new"
    rm -rf "$temporary"
    mkdir "$temporary"
    git --git-dir="$repo" archive "refs/heads/$branch" | tar -x -C "$temporary"
    python3 "$temporary/scripts/check-site.py"
    mv "$temporary" "$release"
fi
ln -sfn "$release/site" "$root/current.next"
mv -Tf "$root/current.next" "$root/current"
chmod -R a+rX "$release"
EOF
sed -i -e "s#__REPO_DIR__#$REPO_DIR#g" -e "s#__SITE_DIR__#$SITE_DIR#g" -e "s#__BRANCH__#$BRANCH#g" "$UPDATE_SCRIPT"
chmod 0755 "$UPDATE_SCRIPT"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Update the Cix Project website from GitHub
[Service]
Type=oneshot
ExecStart=$UPDATE_SCRIPT
EOF
cat > "$TIMER_FILE" <<'EOF'
[Unit]
Description=Check for Cix Project website updates
[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true
[Install]
WantedBy=timers.target
EOF

cat > "$CIX_CADDYFILE" <<EOF
# Managed by the-cix-project-website installer.
$DOMAIN www.$DOMAIN {
    root * $SITE_DIR/current
    encode zstd gzip
    header {
        Content-Security-Policy "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'"
        Referrer-Policy "strict-origin-when-cross-origin"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Permissions-Policy "camera=(), microphone=(), geolocation=()"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        Cache-Control "public, max-age=300"
    }
    @immutable path /assets/*
    header @immutable Cache-Control "public, max-age=31536000, immutable"
    file_server
    handle_errors {
        @not_found expression {http.error.status_code} == 404
        rewrite @not_found /404.html
        file_server
    }
}
EOF
if [ ! -e "$CADDYFILE" ]; then
    printf '%s\n' "import $CADDY_SITES_DIR/*.caddy" > "$CADDYFILE"
elif ! grep -Fq "import $CADDY_SITES_DIR/*.caddy" "$CADDYFILE"; then
    printf '\n%s\n' "import $CADDY_SITES_DIR/*.caddy" >> "$CADDYFILE"
fi

"$UPDATE_SCRIPT"
caddy validate --config "$CADDYFILE"
systemctl daemon-reload
systemctl enable --now the-cix-project-website-update.timer
systemctl enable caddy
if systemctl is-active --quiet caddy; then systemctl reload caddy; else systemctl start caddy; fi
echo "Installed https://$DOMAIN; manual update: systemctl start the-cix-project-website-update.service"
