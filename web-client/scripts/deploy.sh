#!/usr/bin/env bash
# Run on the existing Teno server after uploading a verified release archive.
set -euo pipefail
release=${1:?Release directory name required}
archive=${2:?Absolute archive path required}
case "$release" in *[!a-zA-Z0-9._-]*|'') echo 'Invalid release name' >&2; exit 1;; esac
root=/opt/teno-web-preview
backend=/opt/pocket-backend
backup=/var/backups/teno-web-preview/$release
test ! -e "$root/releases/$release"
sudo install -d -m 755 "$root/releases/$release" "$root/deploy"
sudo install -d -m 700 "$backup"
sudo cp "$backend/Caddyfile" "$backup/Caddyfile"
sudo cp "$backend/compose.yaml" "$backup/backend-compose.yaml"
sudo -u ubuntu git -C "$backend" bundle create "/home/ubuntu/teno-web-$release.bundle" --all
sudo mv "/home/ubuntu/teno-web-$release.bundle" "$backup/backend.bundle"
sudo sh -c 'cd /opt/pocket-backend && docker compose ps --format json > "$1/services-before.json"' sh "$backup"
sudo tar -xzf "$archive" -C "$root/releases/$release"
test -f "$root/releases/$release/index.html"
sudo python3 - "$root/releases/$release" <<'PY'
from pathlib import Path
import sys,json,hashlib
root=Path(sys.argv[1]);manifest=json.loads((root/'release.json').read_text())
for name,digest in manifest['files'].items():
    path=(root/name).resolve()
    assert path.is_relative_to(root.resolve()) and path.is_file(),name
    assert hashlib.sha256(path.read_bytes()).hexdigest()==digest,name
print('Verified release files:',len(manifest['files']))
PY
sudo cp "$root/releases/$release/deploy/Caddyfile" "$root/deploy/Caddyfile"
sudo cp "$root/releases/$release/deploy/compose.yaml" "$root/deploy/compose.yaml"
sudo python3 - "$root" "$release" "$backup" <<'PY'
from pathlib import Path
import sys,os
root=Path(sys.argv[1]); release=sys.argv[2]; backup=Path(sys.argv[3]); current=root/'current'
(backup/'previous-release.txt').write_text(os.readlink(current) if current.is_symlink() else '',encoding='utf-8')
temp=root/('current-'+release);temp.symlink_to('releases/'+release);os.replace(temp,current)
PY
sudo docker compose -f "$root/deploy/compose.yaml" up -d --pull never
# Only add the dedicated /app route. Keep the original API/team routing intact.
sudo python3 - "$backend/Caddyfile" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text()
if 'teno-web-preview:8080' not in s:
    old='    reverse_proxy api:8000'
    assert s.count(old)==1,'Unexpected gateway configuration; no changes made'
    s=s.replace(old,'''    redir /app /app/ 308
    handle_path /app/* {
        reverse_proxy teno-web-preview:8080
    }
    handle {
        reverse_proxy api:8000
    }''')
    p.write_text(s)
PY
if ! sudo docker compose -f "$backend/compose.yaml" exec -T gateway caddy validate --config /etc/caddy/Caddyfile; then
  sudo sh -c 'cat "$1/Caddyfile" > /opt/pocket-backend/Caddyfile' sh "$backup"
  exit 1
fi
sudo docker compose -f "$backend/compose.yaml" exec -T gateway caddy reload --config /etc/caddy/Caddyfile
sudo sh -c 'cd /opt/pocket-backend && docker compose ps --format json > "$1/services-after.json"' sh "$backup"
echo "Web release: $release; gateway backup: $backup"
