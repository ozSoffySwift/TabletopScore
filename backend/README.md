# TableScore backend (PocketBase on Oracle Cloud Always Free)

One VM.Standard.A1.Flex (2 OCPU / 12 GB, Ubuntu 24.04 arm64) running
[PocketBase](https://pocketbase.io) behind Caddy (automatic Let's Encrypt
HTTPS). Everything here is scripted and idempotent.

| | |
|---|---|
| Server IP | _fill in after `provision.sh`_ |
| Domain | _fill in (Caddy needs it for TLS)_ |
| Admin UI | `https://DOMAIN/_/` (superuser credentials are yours alone — never committed) |
| App manifest | `https://DOMAIN/api/catalog.json` |
| Stats | `https://DOMAIN/api/stats/summary` (superuser token required) |
| PocketBase | pinned in `setup_server.sh` (`PB_VERSION`) |

## Runbook

```sh
# 1. Provision (retries every AD; rerun later if ARM capacity is dry)
sh backend/provision.sh

# 2. Point the domain / DuckDNS subdomain at the printed public IP

# 3. Install + configure the server (idempotent; rerun any time)
DOMAIN=your-domain sh backend/deploy.sh SERVER_IP

# 4. First deploy only: create the superuser (interactive, on the server)
ssh -i backend/keys/tablescore_ed25519 ubuntu@SERVER_IP
sudo -u pocketbase /opt/pocketbase/pocketbase superuser upsert EMAIL PASSWORD --dir /opt/pocketbase/pb_data

# 5. Migrate content (uploads ~500 MB of audio on first run)
PB_URL=https://your-domain PB_ADMIN_EMAIL=... PB_ADMIN_PASSWORD=... \
  python3 backend/migrate_content.py
```

## Editing content through the admin UI

Log into `https://DOMAIN/_/`. Collections: `categories`, `tracks`,
`playlists`, `games` (public-read, admin-write) and `events` (anonymous
analytics, create-only for clients).

- **New track:** add a `tracks` record (slug like `km-title-name`, upload the
  MP3 to `audio`, fill composer/license/creditText — LICENSING.md rules
  apply: CC-BY / Pixabay / PD only, never CC-NC). Then open the playlist and
  add the track to its `tracks` relation — **relation order is the play
  order**.
- **New game:** add a `games` record; `playlist` must point at exactly one
  playlist (that's the whole curation model).

**Propagation:** the app fetches `/api/catalog.json`, whose `version` is the
newest `updated` timestamp across content collections — so any admin edit
bumps it automatically. Clients pick it up on next launch (ETag'd; served
with a 5-minute cache, so worst case an edit takes ~5 min + next app launch).

## App integration

`PocketBaseCatalogSource` in the iOS app points at
`BackendConfig.baseURL` (single constant in `TableScore/App/BackendConfig.swift`).
DEBUG builds default to the bundled fixture; launch argument
`-UseRemoteCatalog` switches a DEBUG build to the server. Release builds
always use the server.

Analytics: the app POSTs `events` records (play_started, playlist_completed,
game_opened) with an anonymous per-install UUID. Failures are silently
dropped; the Settings toggle "Share anonymous usage data" stops sending
immediately.

## Updating PocketBase

PocketBase is **pre-1.0**: hook/migration APIs change between minor versions.
Before bumping `PB_VERSION` in `setup_server.sh`:
1. Read the release notes for breaking changes (especially `pb_hooks` APIs).
2. Snapshot: `sudo tar czf /opt/backups/pre-upgrade.tar.gz -C /opt/pocketbase pb_data`
3. Bump the version, rerun `deploy.sh`, check `journalctl -u pocketbase` for
   hook errors and hit `/api/catalog.json`.

## Backups

Nightly to `/opt/backups`, 14-day retention — see [restore.md](restore.md),
including why you should pull copies off the box (Oracle reclaims idle
Always-Free instances).
