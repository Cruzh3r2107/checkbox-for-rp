#!/usr/bin/env bash
# Generic Checkbox run helper. Host-only, NO SSH.
#
# Drop a copy of this into any board folder that has an *-env-setup.yaml, a
# launcher-*, and a .local.env (copied from .local.env.example). It reads the
# DEVICE_* values from .local.env, renders the config into .run/ (gitignored),
# and drives the whole flow:
#   render -> ping -> provision (Envicorn) -> verify -> test -> collect
#
# It auto-discovers the env-setup YAML and launcher in its own folder, so the
# same script works for every board. Placeholders filled during render:
#   <DEVICE_IP> <USER> <PASSWORD> <WIFI_SSID> <WIFI_PSK> <WATCHDOG_MODULE>
#
# IMPORTANT: never TCP-probe port 18871 while a control session is live (it
# hijacks/kills the run). `verify` is for BEFORE a run only.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$DIR/.local.env"; RUN="$DIR/.run"; REPORTS="$DIR/reports"

die() { echo "ERROR: $*" >&2; exit "${2:-1}"; }

load_env() {
  [ -f "$ENVF" ] || die ".local.env missing - copy .local.env.example to .local.env and fill it in" 3
  set -a; # shellcheck disable=SC1090
  source "$ENVF"; set +a
  # Accept legacy PI_*/KRIA_* names as a fallback for the standardized DEVICE_*.
  : "${DEVICE_IP:=${PI_IP:-${KRIA_IP:-}}}"
  : "${DEVICE_USER:=${PI_USER:-${KRIA_USER:-}}}"
  : "${DEVICE_PASSWORD:=${PI_PASSWORD:-${KRIA_PASSWORD:-}}}"
  : "${DEVICE_IP:?set DEVICE_IP in .local.env}"
  : "${DEVICE_USER:?set DEVICE_USER in .local.env}"
}

find_one() {  # find_one <glob> <description>
  local m; m="$(ls "$DIR"/$1 2>/dev/null | head -1)"
  [ -n "$m" ] || die "no file matching '$1' in $(basename "$DIR")/ ($2)" 7
  echo "$m"
}

render() {
  load_env; mkdir -p "$RUN"
  local yaml launcher f
  yaml="$(find_one '*-env-setup.yaml' 'Envicorn provisioning file')"
  launcher="$(find_one 'launcher-*' 'Checkbox launcher')"
  for f in "$yaml" "$launcher"; do
    # <DEVICE_IP> is the template placeholder; <PI_IP>/<KRIA_IP> are the legacy
    # per-board ones, so the same script renders any folder's config files.
    sed -e "s|<DEVICE_IP>|${DEVICE_IP}|g" \
        -e "s|<PI_IP>|${DEVICE_IP}|g" \
        -e "s|<KRIA_IP>|${DEVICE_IP}|g" \
        -e "s|<USER>|${DEVICE_USER}|g" \
        -e "s|<PASSWORD>|${DEVICE_PASSWORD}|g" \
        -e "s|<WIFI_SSID>|${WIFI_SSID:-}|g" \
        -e "s|<WIFI_PSK>|${WIFI_PSK:-}|g" \
        -e "s|<WATCHDOG_MODULE>|${WATCHDOG_MODULE:-}|g" \
        "$f" > "$RUN/$(basename "$f")"
  done
  chmod 600 "$RUN/$(basename "$yaml")"
  echo "rendered -> $RUN/ (gitignored)"
}

rendered_yaml()     { echo "$RUN/$(basename "$(find_one '*-env-setup.yaml' yaml)")"; }
rendered_launcher() { echo "$RUN/$(basename "$(find_one 'launcher-*' launcher)")"; }

ping_dut() {
  load_env
  ping -c2 -W2 "$DEVICE_IP" >/dev/null 2>&1 && echo "DUT UP at $DEVICE_IP" \
    || die "DUT unreachable at $DEVICE_IP" 4
}

provision() {
  render
  local yaml; yaml="$(rendered_yaml)"
  echo "Provisioning $DEVICE_IP via Envicorn..."
  if [ -n "${DEVICE_PASSWORD:-}" ]; then
    ceqa-env-setup-tools.test-env-setup setup -f "$yaml" \
      --remote-ip "$DEVICE_IP" --username "$DEVICE_USER" --password "$DEVICE_PASSWORD"
  else
    # No password set: Core authenticates with the imported SSH key.
    ceqa-env-setup-tools.test-env-setup setup -f "$yaml" \
      --remote-ip "$DEVICE_IP" --username "$DEVICE_USER"
  fi
}

verify() {
  load_env
  ping -c2 -W2 "$DEVICE_IP" >/dev/null 2>&1 || die "DUT not pingable at $DEVICE_IP" 4
  timeout 3 bash -c "echo > /dev/tcp/$DEVICE_IP/18871" 2>/dev/null \
    && echo "18871 OPEN - agent listening" || die "18871 CLOSED - re-run provision" 5
}

test_run() {
  load_env
  local launcher; launcher="$(rendered_launcher)"
  [ -f "$launcher" ] || render
  echo "Running test plan on $DEVICE_IP (streams; ~30-60 min)..."
  checkbox-ce-oem.checkbox-cli control "$DEVICE_IP" "$launcher"
}

collect() {
  mkdir -p "$REPORTS"
  local src="$HOME/.local/share/checkbox-ng" latest stamp
  latest="$(ls -t "$src"/submission_*.junit.xml 2>/dev/null | head -1)"
  [ -n "$latest" ] || die "no submission_*.junit.xml found in $src" 6
  stamp="$(basename "$latest" .junit.xml)"
  cp "$src/$stamp".{json,junit.xml,html,tar.xz} "$REPORTS/" 2>/dev/null || true
  echo "copied $stamp.* -> $REPORTS/"
  # JSON is bundled inside the tar.xz as submission.json; extract it.
  if [ -f "$REPORTS/$stamp.tar.xz" ]; then
    tar xJf "$REPORTS/$stamp.tar.xz" submission.json -O > "$REPORTS/$stamp.json" 2>/dev/null \
      && echo "extracted $stamp.json" || rm -f "$REPORTS/$stamp.json"
  fi
  python3 - "$REPORTS/$stamp.junit.xml" <<'EOF'
import sys, xml.etree.ElementTree as ET
f=sys.argv[1]; p=fa=sk=0; fails=[]
for tc in ET.parse(f).getroot().iter('testcase'):
    if tc.find('failure') is not None: fa+=1; fails.append(tc.get('name',''))
    elif tc.find('skipped') is not None: sk+=1
    else: p+=1
print(f"passed={p} failed={fa} cannot_start={sk}")
if fails:
    print("failed:"); [print("  -", n) for n in fails]
EOF
}

case "${1:-}" in
  render) render ;;
  ping) ping_dut ;;
  provision) provision ;;
  verify) verify ;;
  test) test_run ;;
  collect) collect ;;
  *) echo "usage: $0 {render|ping|provision|verify|test|collect}"; exit 2 ;;
esac
