#!/bin/sh
# Deploy/refresh the TableScore server (idempotent).
#   DOMAIN=tablescore.duckdns.org sh backend/deploy.sh <SERVER_IP>
# Copies pb_migrations + pb_hooks, then runs setup_server.sh over SSH.
set -eu

IP="${1:?usage: DOMAIN=<domain> sh backend/deploy.sh <server-ip>}"
DOMAIN="${DOMAIN:?set DOMAIN}"
DIR="$(dirname "$0")"
KEY="$DIR/keys/tablescore_ed25519"
SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new ubuntu@$IP"

echo "== copying migrations + hooks =="
scp -i "$KEY" -o StrictHostKeyChecking=accept-new -r "$DIR/pb_migrations" "$DIR/pb_hooks" "ubuntu@$IP:/tmp/"

echo "== running setup on server =="
$SSH "sudo DOMAIN=$DOMAIN PB_VERSION=${PB_VERSION:-0.29.3} bash -s" < "$DIR/setup_server.sh"
$SSH "sudo cp -r /tmp/pb_migrations/* /opt/pocketbase/pb_migrations/ 2>/dev/null; \
      sudo cp -r /tmp/pb_hooks/* /opt/pocketbase/pb_hooks/ 2>/dev/null; \
      sudo chown -R pocketbase:pocketbase /opt/pocketbase; \
      sudo systemctl restart pocketbase && sleep 2 && systemctl is-active pocketbase"

echo ""
echo "Server deployed. Admin UI: https://$DOMAIN/_/"
echo "If this is the first deploy, create the superuser now:"
echo "  ssh -i $KEY ubuntu@$IP"
echo "  sudo -u pocketbase /opt/pocketbase/pocketbase superuser upsert YOUR_EMAIL YOUR_PASSWORD --dir /opt/pocketbase/pb_data"
