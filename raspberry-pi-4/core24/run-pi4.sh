#!/usr/bin/env bash
# Pi 4 UC24 Checkbox runner — host-only, NO SSH.
# Secrets come from .local.env (gitignored). Rendered configs go to .run/ (gitignored).
# Usage: bash run-pi4.sh {render|ping|provision|verify|test|collect}
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE=".local.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE missing. Copy .local.env.example to .local.env and fill it in (one-time)." >&2
  exit 3
fi
set -a; . "$ENV_FILE"; set +a

RUN=".run"
mkdir -p "$RUN" reports

render() {
  # YAML no longer carries placeholders (networking pinned at the router; no
  # snap-refresh). Only the launcher needs the WiFi creds; IP/user/password go
  # straight to Envicorn. Substitution is harmless on files without placeholders.
  for f in pi4-uc24-env-setup.yaml launcher-pi4-uc24; do
    sed -e "s|<PI_IP>|${PI_IP}|g" \
        -e "s|<USER>|${PI_USER}|g" \
        -e "s|<PASSWORD>|${PI_PASSWORD}|g" \
        -e "s|<WIFI_SSID>|${WIFI_SSID}|g" \
        -e "s|<WIFI_PSK>|${WIFI_PSK}|g" \
        "$f" > "$RUN/$f"
  done
  echo "rendered filled configs into $RUN/"
}

case "${1:-}" in
  render)
    render ;;

  ping)
    ping -c 2 -W 2 "$PI_IP" ;;

  provision)
    render
    ceqa-env-setup-tools.test-env-setup setup \
      -f "$RUN/pi4-uc24-env-setup.yaml" \
      --remote-ip "$PI_IP" --username "$PI_USER" --password "$PI_PASSWORD" ;;

  verify)
    ping -c 2 -W 2 "$PI_IP" >/dev/null || { echo "UNREACHABLE"; exit 4; }
    if timeout 3 bash -c "echo > /dev/tcp/$PI_IP/18871" 2>/dev/null; then
      echo "18871 OPEN — agent ready"
    else
      echo "18871 CLOSED — provisioning incomplete"; exit 5
    fi ;;

  test)
    render
    checkbox-ce-oem.checkbox-cli control "$PI_IP" "$RUN/launcher-pi4-uc24" ;;

  collect)
    latest=$(ls -t ~/.local/share/checkbox-ng/submission_*.junit.xml 2>/dev/null | head -1)
    [ -n "$latest" ] || { echo "no submission files found"; exit 6; }
    base="${latest%.junit.xml}"
    cp "$base".* reports/ 2>/dev/null || true
    echo "copied $(basename "$base").* into reports/"
    # checkbox bundles the full JSON inside the tar.xz as submission.json
    # (the `json` stock_report keyword is a no-op). Extract it as <stamp>.json.
    stamp=$(basename "$base")
    if [ -f "reports/$stamp.tar.xz" ]; then
      tar xJf "reports/$stamp.tar.xz" submission.json -O > "reports/$stamp.json" 2>/dev/null \
        && echo "extracted $stamp.json" || rm -f "reports/$stamp.json"
    fi
    python3 - "$latest" <<'PY'
import sys, xml.etree.ElementTree as ET
f = sys.argv[1]
p = fail = skip = 0
fails = []
for tc in ET.parse(f).getroot().iter('testcase'):
    name = tc.get('name', '')
    if tc.find('failure') is not None:
        fail += 1; fails.append(name)
    elif tc.find('skipped') is not None:
        skip += 1
    else:
        p += 1
print(f"passed={p} failed={fail} cannot_start={skip}")
print("FAILED_TESTS:")
for t in fails:
    print("  " + t)
PY
    ;;

  *)
    echo "usage: $0 {render|ping|provision|verify|test|collect}" >&2
    exit 2 ;;
esac
