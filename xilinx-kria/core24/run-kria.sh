#!/usr/bin/env bash
# Kria KV260 (Ubuntu Core 24) - Checkbox run helper. Host-only, NO SSH.
# Mirrors the Pi 4 UC24 flow: agent is checkbox.agent, test plan is
# client-cert-iot-ubuntucore-24-automated. Secrets live in .local.env (gitignored);
# rendered configs go to .run/ (gitignored).
# Flow: render -> ping -> provision (Envicorn) -> verify -> test -> collect.
# IMPORTANT: never TCP-probe port 18871 while a control session is live (it
# hijacks/kills the run). `verify` is for BEFORE a run only.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$DIR/.local.env"
RUN="$DIR/.run"
REPORTS="$DIR/reports"

die() { echo "ERROR: $*" >&2; exit "${2:-1}"; }

load_env() {
  [ -f "$ENVF" ] || die ".local.env missing - copy .local.env.example to .local.env and fill it in" 3
  set -a; # shellcheck disable=SC1090
  source "$ENVF"; set +a
  : "${KRIA_IP:?set KRIA_IP in .local.env}"
  : "${KRIA_USER:?set KRIA_USER in .local.env}"
  : "${KRIA_PASSWORD:?set KRIA_PASSWORD in .local.env}"
}

render() {
  load_env; mkdir -p "$RUN"
  sed -e "s|<KRIA_IP>|$KRIA_IP|g" -e "s|<USER>|$KRIA_USER|g" -e "s|<PASSWORD>|$KRIA_PASSWORD|g" \
      "$DIR/kria-core24-env-setup.yaml" > "$RUN/kria-core24-env-setup.yaml"
  cp "$DIR/launcher-kria-kv260-core24" "$RUN/launcher-kria-kv260-core24"
  echo "rendered -> $RUN/ (gitignored)"
}

ping_dut() { load_env; ping -c2 -W2 "$KRIA_IP" >/dev/null 2>&1 && echo "Kria UP at $KRIA_IP" || die "Kria unreachable at $KRIA_IP" 4; }

provision() {
  render
  echo "Provisioning $KRIA_IP via Envicorn (checkbox devmode + docker; ~5-15 min)..."
  ceqa-env-setup-tools.test-env-setup setup \
    -f "$RUN/kria-core24-env-setup.yaml" \
    --remote-ip "$KRIA_IP" --username "$KRIA_USER" --password "$KRIA_PASSWORD"
}

verify() {
  load_env
  ping -c2 -W2 "$KRIA_IP" >/dev/null 2>&1 || die "Kria not pingable at $KRIA_IP" 4
  timeout 3 bash -c "echo > /dev/tcp/$KRIA_IP/18871" 2>/dev/null \
    && echo "18871 OPEN - checkbox.agent listening" || die "18871 CLOSED - re-run provision" 5
}

test_run() {
  load_env; [ -f "$RUN/launcher-kria-kv260-core24" ] || render
  echo "Running test plan on $KRIA_IP (streams; ~30-60 min)..."
  checkbox-ce-oem.checkbox-cli control "$KRIA_IP" "$RUN/launcher-kria-kv260-core24"
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
