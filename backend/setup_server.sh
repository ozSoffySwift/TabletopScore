#!/bin/bash
# TableScore server setup (Phase 2). Runs ON the instance as root.
# Idempotent — safe to rerun. Invoked by deploy.sh; expects env:
#   DOMAIN      e.g. tablescore.duckdns.org (required — Caddy needs it for TLS)
#   PB_VERSION  PocketBase release to install (pinned; see note below)
set -euo pipefail

DOMAIN="${DOMAIN:?set DOMAIN (e.g. tablescore.duckdns.org)}"
# Pinned deliberately: PocketBase is pre-1.0 and hook/migration APIs move
# between minors. Read release notes + snapshot pb_data before bumping.
PB_VERSION="${PB_VERSION:-0.29.3}"

export DEBIAN_FRONTEND=noninteractive

echo "== system updates + packages =="
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq fail2ban ufw curl unzip debian-keyring debian-archive-keyring apt-transport-https

echo "== firewall (ufw 22/80/443) =="
ufw allow 22/tcp >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null

echo "== oracle iptables gotcha: allow 80/443 before the REJECT rule =="
# Oracle Ubuntu images ship /etc/iptables/rules.v4 with a REJECT-all beyond
# the security list. Insert ACCEPTs ahead of it and persist.
for PORT in 80 443; do
    iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 5 -p tcp --dport "$PORT" -j ACCEPT
done
command -v netfilter-persistent >/dev/null && netfilter-persistent save >/dev/null || true

echo "== pocketbase $PB_VERSION =="
id -u pocketbase >/dev/null 2>&1 || useradd --system --create-home --home-dir /opt/pocketbase --shell /usr/sbin/nologin pocketbase
mkdir -p /opt/pocketbase /opt/backups
CURRENT=$(/opt/pocketbase/pocketbase --version 2>/dev/null | grep -o '[0-9][0-9.]*' || true)
if [ "$CURRENT" != "$PB_VERSION" ]; then
    curl -fsSL -o /tmp/pb.zip "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_arm64.zip"
    unzip -o -q /tmp/pb.zip pocketbase -d /opt/pocketbase
    rm /tmp/pb.zip
fi
mkdir -p /opt/pocketbase/pb_data /opt/pocketbase/pb_migrations /opt/pocketbase/pb_hooks
chown -R pocketbase:pocketbase /opt/pocketbase /opt/backups
chmod +x /opt/pocketbase/pocketbase

echo "== systemd unit =="
cat > /etc/systemd/system/pocketbase.service <<'UNIT'
[Unit]
Description=PocketBase (TableScore)
After=network.target

[Service]
Type=simple
User=pocketbase
Group=pocketbase
WorkingDirectory=/opt/pocketbase
ExecStart=/opt/pocketbase/pocketbase serve \
    --http=127.0.0.1:8090 \
    --dir=/opt/pocketbase/pb_data \
    --migrationsDir=/opt/pocketbase/pb_migrations \
    --hooksDir=/opt/pocketbase/pb_hooks
Restart=always
RestartSec=3
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now pocketbase

echo "== caddy (auto-HTTPS via Let's Encrypt) =="
if ! command -v caddy >/dev/null; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -qq && apt-get install -y -qq caddy
fi
cat > /etc/caddy/Caddyfile <<CADDY
$DOMAIN {
    reverse_proxy 127.0.0.1:8090
    encode gzip
}
CADDY
systemctl reload caddy || systemctl restart caddy

echo "== nightly backups (14-day retention) =="
cat > /etc/cron.d/pocketbase-backup <<'CRON'
30 3 * * * root systemctl stop pocketbase && tar czf /opt/backups/pb_data_$(date +\%Y\%m\%d).tar.gz -C /opt/pocketbase pb_data && systemctl start pocketbase && find /opt/backups -name 'pb_data_*.tar.gz' -mtime +14 -delete
CRON

systemctl restart pocketbase
echo ""
echo "DONE. Create the superuser interactively (never scripted/committed):"
echo "  sudo -u pocketbase /opt/pocketbase/pocketbase superuser upsert YOUR_EMAIL YOUR_PASSWORD --dir /opt/pocketbase/pb_data"
echo "Admin UI: https://$DOMAIN/_/"
