# Backup & restore

**Why this matters:** Oracle can reclaim idle Always-Free instances (they
warn by email, but not always with much notice). The nightly backup is the
safety net — with it, a reclaimed instance costs an hour, not the catalog.

## What's backed up

A cron job (`/etc/cron.d/pocketbase-backup`) stops PocketBase at 03:30,
tars `/opt/pocketbase/pb_data` (database + all uploaded media) to
`/opt/backups/pb_data_YYYYMMDD.tar.gz`, restarts, and keeps 14 days.

**Pull a copy off the server regularly** — a backup on the same reclaimable
instance protects against corruption, not reclamation:

```sh
scp -i backend/keys/tabletopscore_ed25519 \
  ubuntu@SERVER_IP:/opt/backups/pb_data_$(date +%Y%m%d).tar.gz ~/tabletopscore-backups/
```

## Restore onto a fresh instance

1. Provision + set up a new instance (`sh backend/provision.sh`, then
   `DOMAIN=... sh backend/deploy.sh NEW_IP`). Update DNS/DuckDNS to the new IP.
2. Stop PocketBase and unpack the backup:
   ```sh
   ssh -i backend/keys/tabletopscore_ed25519 ubuntu@NEW_IP
   sudo systemctl stop pocketbase
   sudo tar xzf /path/to/pb_data_YYYYMMDD.tar.gz -C /opt/pocketbase
   sudo chown -R pocketbase:pocketbase /opt/pocketbase/pb_data
   sudo systemctl start pocketbase
   ```
3. Verify: `https://DOMAIN/api/catalog.json` returns the catalog, and the
   admin UI (`https://DOMAIN/_/`) accepts your superuser login (credentials
   live in pb_data, so they come back with the restore).

Worst case with no backup: rerun `backend/migrate_content.py` — the entire
catalog is reproducible from this repo; only `events` analytics would be lost.
