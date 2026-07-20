#!/bin/sh
# Dev-only static file server for box art. The dev fixture's artwork URLs
# point at http://localhost:8787/art/<game-id>.jpg; run this alongside the
# simulator. If it isn't running, the app just shows placeholder art.
cd "$(dirname "$0")/../DevCDN" || exit 1
echo "Serving DevCDN at http://localhost:8787 (ctrl-c to stop)"
exec python3 -m http.server 8787
