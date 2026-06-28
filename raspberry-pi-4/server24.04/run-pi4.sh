#!/usr/bin/env bash
# Raspberry Pi 4 (Ubuntu Server 24.04) — Checkbox run helper. Host-only, NO SSH.
# Server model: agent is checkbox-ce-oem.remote-slave, plan is the ce-oem contrib
# server plan. Secrets in .local.env (gitignored); rendered configs in .run/.
# Flow: render -> ping -> provision (Envicorn) -> verify -> test -> collect.
# IMPORTANT: never TCP-probe port 18871 while a control session is live — it
# hijacks/kills the run. `verify` is for BEFORE a run only.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$DIR/.local.env"; RUN="$DIR/.run"; REPORTS="$DIR/reports"

die() { echo "ERROR: $*" >&2; exit "${2:-1}"; }

load_env() {
  [ -f "$ENVF" ] || die ".local.env missing — copy .local.env.example to .local.env and fill it in" 3
  set -a; # shellcheck disable=SC1090
  source "$ENVF"; set +a
  : "${PI_IP:?set PI_IP}"; : "${PI_USER:?set PI_USER}"; : "${PI_PASSWORD:?set PI_PASSWORD}"
  : "${WIFI_SSID:?set WIFI_SSID}"; : "${WIFI_PSK:?set WIFI_PSK}"
}

render() {
  load_env; mkdir -p "$RUN"
  sed -e "s|<USER>|$PI_USER|g" -e "s|<PASSWORD>|$PI_PASSWORD|g" \
      "$DIR/pi4-server2404-env-setup.yaml" > "$RUN/pi4-server2404-env-setup.yaml"
  sed -e "s|<WIFI_SSID>|$WIFI_SSID|g" -e "s|<WIFI_PSK>|$WIFI_PSK|g" \
      "$DIR/launcher-pi4-server2404" > "$RUN/launcher-pi4-server2404"
  chmod 600 "$RUN/pi4-server2404-env-setup.yaml"
  echo "rendered -> $RUN/ (gitignored)"
}

ping_dut() { load_env; ping -c2 -W2 "$PI_IP" >/dev/null 2>&1 && echo "Pi UP at $PI_IP" || die "Pi unreachable at $PI_IP" 4; }

provision() {
  render
  echo "Provisioning $PI_IP via Envicorn (snaps + debs + docker; ~10-20 min)..."
  ceqa-env-setup-tools.test-env-setup setup \
    -f "$RUN/pi4-server2404-env-setup.yaml" \
    --remote-ip "$PI_IP" --username "$PI_USER" --password "$PI_PASSWORD"
}

verify() {
  load_env
  ping -c2 -W2 "$PI_IP" >/dev/null 2>&1 || die "Pi not pingable at $PI_IP" 4
  timeout 3 bash -c "echo > /dev/tcp/$PI_IP/18871" 2>/dev/null \
    && echo "18871 OPEN — checkbox-ce-oem.remote-slave listening" || die "18871 CLOSED — re-run provision" 5
}

test_run() {
  load_env; [ -f "$RUN/launcher-pi4-server2404" ] || render
  echo "Running test plan on $PI_IP (streams; ~30-60 min)..."
  checkbox-ce-oem.checkbox-cli control "$PI_IP" "$RUN/launcher-pi4-server2404"
}

collect() {
  mkdir -p "$REPORTS"
  local src="$HOME/.local/share/checkbox-ng" latest stamp
  latest="$(ls -t "$src"/submission_*.junit.xml 2>/dev/null | head -1)"
  [ -n "$latest" ] || die "no submission_*.junit.xml found in $src" 6
  stamp="$(basename "$latest" .junit.xml)"
  cp "$src/$stamp".{json,junit.xml,html,tar.xz} "$REPORTS/" 2>/dev/null || true
  echo "copied $stamp.* -> $REPORTS/"
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
  render) render ;; ping) ping_dut ;; provision) provision ;;
  verify) verify ;; test) test_run ;; collect) collect ;;
  *) echo "usage: $0 {render|ping|provision|verify|test|collect}"; exit 2 ;;
esac
