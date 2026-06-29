#!/usr/bin/env bash
# Kria KV260 (Ubuntu Server 24.04) - Checkbox run helper.
# All real values live in .local.env (gitignored). This script renders the
# public templates into .run/ (gitignored) with your values, then drives the
# host-only flow: ping -> provision (Envicorn) -> verify -> test -> collect.
# NO SSH is performed here; Envicorn handles the DUT side internally.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$DIR/.local.env"
RUN="$DIR/.run"
REPORTS="$DIR/reports"

die() { echo "ERROR: $*" >&2; exit "${2:-1}"; }

load_env() {
  [ -f "$ENVF" ] || die ".local.env missing - copy .local.env.example to .local.env and fill it in" 3
  # shellcheck disable=SC1090
  set -a; source "$ENVF"; set +a
  : "${KRIA_IP:?set KRIA_IP in .local.env}"
  : "${KRIA_USER:?set KRIA_USER in .local.env}"
  : "${KRIA_PASSWORD:?set KRIA_PASSWORD in .local.env}"
}

render() {
  load_env
  mkdir -p "$RUN"
  sed -e "s|<KRIA_IP>|$KRIA_IP|g" \
      -e "s|<USER>|$KRIA_USER|g" \
      -e "s|<PASSWORD>|$KRIA_PASSWORD|g" \
      "$DIR/kria-server2404-env-setup.yaml" > "$RUN/kria-server2404-env-setup.yaml"
  cp "$DIR/launcher-kria-kv260-server2404" "$RUN/launcher-kria-kv260-server2404"
  chmod 600 "$RUN/kria-server2404-env-setup.yaml"
  echo "rendered -> $RUN/ (gitignored)"
}

ping_dut() {
  load_env
  if ping -c2 -W2 "$KRIA_IP" >/dev/null 2>&1; then
    echo "Kria UP at $KRIA_IP"
  else
    die "Kria unreachable at $KRIA_IP - check power/Ethernet/IP" 4
  fi
}

provision() {
  render
  echo "Provisioning $KRIA_IP via Envicorn (installs snaps + debs + docker; ~10-20 min)..."
  ceqa-env-setup-tools.test-env-setup setup \
    -f "$RUN/kria-server2404-env-setup.yaml" \
    --remote-ip "$KRIA_IP" --username "$KRIA_USER" --password "$KRIA_PASSWORD"
}

verify() {
  load_env
  ping -c2 -W2 "$KRIA_IP" >/dev/null 2>&1 || die "Kria not pingable at $KRIA_IP" 4
  if timeout 3 bash -c "echo > /dev/tcp/$KRIA_IP/18871" 2>/dev/null; then
    echo "18871 OPEN - checkbox-ce-oem.remote-slave is listening"
  else
    die "18871 CLOSED - agent not up; re-run provision" 5
  fi
}

test_run() {
  load_env
  [ -f "$RUN/launcher-kria-kv260-server2404" ] || render
  echo "Running test plan on $KRIA_IP (streams; ~30-60 min)..."
  checkbox-ce-oem.checkbox-cli control "$KRIA_IP" "$RUN/launcher-kria-kv260-server2404"
}

collect() {
  mkdir -p "$REPORTS"
  local src="$HOME/.local/share/checkbox-ng"
  local latest
  latest="$(ls -t "$src"/submission_*.junit.xml 2>/dev/null | head -1 || true)"
  [ -n "$latest" ] || die "no submission_*.junit.xml found in $src" 6
  local stamp; stamp="$(basename "$latest" .junit.xml)"
  cp "$src/$stamp".{json,junit.xml,html,tar.xz} "$REPORTS/" 2>/dev/null || true
  echo "copied $stamp.* -> $REPORTS/"
  # checkbox bundles the full JSON inside the tar.xz as submission.json (the
  # `json` stock_report keyword is a no-op). Extract it as <stamp>.json.
  if [ -f "$REPORTS/$stamp.tar.xz" ]; then
    tar xJf "$REPORTS/$stamp.tar.xz" submission.json -O > "$REPORTS/$stamp.json" 2>/dev/null \
      && echo "extracted $stamp.json" || rm -f "$REPORTS/$stamp.json"
  fi
  python3 - "$REPORTS/$stamp.junit.xml" <<'EOF'
import sys, xml.etree.ElementTree as ET
f = sys.argv[1]
p=fail=skip=0; fails=[]
for tc in ET.parse(f).getroot().iter('testcase'):
    if tc.find('failure') is not None:
        fail+=1; fails.append(tc.get('name',''))
    elif tc.find('skipped') is not None: skip+=1
    else: p+=1
print(f"passed={p} failed={fail} cannot_start={skip}")
if fails:
    print("failed tests:")
    for n in fails: print(f"  - {n}")
EOF
}

case "${1:-}" in
  render)    render ;;
  ping)      ping_dut ;;
  provision) provision ;;
  verify)    verify ;;
  test)      test_run ;;
  collect)   collect ;;
  *) echo "usage: $0 {render|ping|provision|verify|test|collect}"; exit 2 ;;
esac
