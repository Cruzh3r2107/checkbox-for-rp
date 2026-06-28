# Raspberry Pi 4 - Ubuntu Core 24 Checkbox Setup

Rapid-prototyping certification run for Raspberry Pi 4 on **Ubuntu Core 24**.
All steps run **from the host** - never SSH into the Pi. Envicorn handles the
Pi-side configuration over SSH internally; the Checkbox controller talks to the
agent on port 18871.

## Fill these in for your environment

Replace the placeholders below wherever they appear in the commands, in
`pi4-uc24-env-setup.yaml`, and in `launcher-pi4-uc24`.

| Placeholder | Meaning |
|-------------|---------|
| `<PI_IP>` | Pi 4 Ethernet IP (also the static IP set during provisioning) |
| `<PI_WIFI_IP>` | Pi 4 WiFi static IP |
| `<USER>` | DUT login user (Ubuntu Core default is `ubuntu`) |
| `<PASSWORD>` | DUT login password |
| `<WIFI_SSID>` / `<WIFI_PSK>` | Lab WiFi credentials |
| `<GATEWAY>` / `<DNS>` | Network gateway and DNS server |
| `<SUBNET>` | Lab subnet prefix, e.g. the first three octets of `<PI_IP>` |

## Starting state (before step 1)

- Pi 4 is **powered on and connected to the lab network by Ethernet** (`end0`).
- Pi reachable at `<PI_IP>` (set by a prior run) or via a DHCP lease - if you
  don't know its IP, scan first:
  ```bash
  for i in $(seq 1 254); do (ping -c1 -W1 <SUBNET>.$i >/dev/null 2>&1 && echo "<SUBNET>.$i UP") & done; wait
  ```
- Host is on the same network with the two snaps below installed.
- Run every command from inside this directory:
  ```bash
  cd raspberry-pi-4
  ```

## Board facts

| Item | Value |
|------|-------|
| OS | Ubuntu Core 24 (arm64) |
| Ethernet | `end0` → `<PI_IP>` |
| WiFi | `wlan0` → `<PI_WIFI_IP>` (`<WIFI_SSID>`) |
| Agent port | 18871 |
| Watchdog | `bcm2835_wdt` |
| RTC | none (`TOTAL_RTC_NUM=0`) |
| WiFi / BT | yes / yes (AC, no ax) |
| Login | user `<USER>`, password `<PASSWORD>` |
| Test plan | `com.canonical.certification::client-cert-iot-ubuntucore-24-automated` |

## Files in this directory

| File | Purpose |
|------|---------|
| `pi4-uc24-env-setup.yaml` | Envicorn provisioning (snaps, static IP, manifest, watchdog, agent) |
| `launcher-pi4-uc24` | Checkbox launcher (test plan + WiFi creds + `TOTAL_RTC_NUM`) |
| `reports/` | Collected json / junit.xml submission files |

## Host prerequisites

```bash
snap list checkbox-ce-oem        # controller CLI (classic)
snap list ceqa-env-setup-tools   # Envicorn (classic)
```
If missing: `sudo snap install checkbox-ce-oem --classic` and
`sudo snap install --dangerous --classic ../envicorn/ceqa-env-setup-tools_0.3_amd64.snap`.

## Steps

### 1. Confirm the Pi is reachable
```bash
ping -c 2 <PI_IP>
```

### 2. Provision with Envicorn
Installs `checkbox` (devmode, uc24/stable) + `bluez`, writes the machine
manifest, loads the `bcm2835_wdt` watchdog, and starts `checkbox.agent`. It does
**not** touch networking (the IP is pinned by the router reservation) and does
**not** run `snap refresh` (see quirks). All actions are idempotent; a failed
action stops the rest - fix and re-run.
```bash
ceqa-env-setup-tools.test-env-setup setup \
  -f pi4-uc24-env-setup.yaml \
  --remote-ip <PI_IP> --username <USER> --password <PASSWORD>
```

### 3. Verify the agent is up (host only)
```bash
ping -c 2 <PI_IP>
(echo >/dev/tcp/<PI_IP>/18871) 2>/dev/null \
  && echo "18871 OPEN - agent ready" || echo "18871 CLOSED - re-run step 2"
```

### 4. Run the tests
Takes ~30–60 min. Streams from the host; the Pi reboots during the run but the
static IP keeps the session alive.
```bash
checkbox-ce-oem.checkbox-cli control <PI_IP> launcher-pi4-uc24
```

### 5. Collect reports
Submission files land in `~/.local/share/checkbox-ng/`. Copy the latest set here:
```bash
cp ~/.local/share/checkbox-ng/submission_*.{json,junit.xml,html} reports/ 2>/dev/null
```
Quick pass/fail/skip count:
```bash
python3 - <<'EOF'
import xml.etree.ElementTree as ET, glob
f = sorted(glob.glob('reports/submission_*.junit.xml'))[-1]
p=f_=s=0
for tc in ET.parse(f).getroot().iter('testcase'):
    if tc.find('failure') is not None: f_+=1
    elif tc.find('skipped') is not None: s+=1
    else: p+=1
print(f"passed={p} failed={f_} cannot_start={s}")
EOF
```

## Known structural failures (cannot fix)

| Test | Reason |
|------|--------|
| `miscellanea/efi_boot_mode` | Pi 4 uses U-Boot, not EFI |
| `bluetooth4/beacon_eddystone_url_hci0` | No EddyStone-URL beacon in lab |
| `wireless/wireless_connection_open_*` | No open WiFi AP in lab |
| `snapd/snap-refresh-*` | Need refreshed snaps past seed revision (handled by step 2) |

A high `cannot_start` count is expected - tests are gated off by the machine
manifest for hardware this unit doesn't have (no RTC, no I2C, no USB storage, etc.).

## Notes / quirks

- **Pin the IP at the router, not the board.** Reserve the Pi's `end0` MAC to a
  fixed address in the router's DHCP settings. Leaving the board on DHCP +
  reservation keeps it reachable through the mid-test reboot; writing a board-side
  netplan static IP (the old approach) dropped it off the network mid-provision.
- **`snap refresh` is intentionally skipped.** On UC24 it triggers kernel/snapd
  reboots that break provisioning. The `snapd/snap-refresh-*` tests fail either
  way (they need beta/candidate channels), so the refresh buys nothing.
- **No SSH for testing.** Provisioning = Envicorn; execution = `checkbox-cli control`;
  verification = ping + port check only.
- **Secrets:** keep real IPs, passwords, and WiFi credentials out of committed
  files. `pi4-uc24-env-setup.yaml` and `launcher-pi4-uc24` contain placeholders -
  fill them in locally and do not commit the filled-in versions.
- **Files are copies** of `../envicorn/pi4-uc24-env-setup.yaml` and
  `../launchers-rp/client-cert-iot/launcher-pi4-uc24`. Edit the copies here for
  Pi-4-specific tuning; the originals remain the templates other boards reference.
