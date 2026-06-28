# Raspberry Pi 4 - Ubuntu Server 24.04 Checkbox Setup

Rapid-prototyping certification run for the Raspberry Pi 4 on **Ubuntu Server
24.04**. Host-driven (no SSH): Envicorn provisions, the Checkbox controller drives
the run, verification is ping + port only.

> Sibling: `../core24/` is the Ubuntu Core 24 variant of the same board (different
> snaps, agent, and test plan).

## Core 24 vs Server 24.04

| | Server 24.04 (here) | Core 24 (`../core24/`) |
|--|--|--|
| Agent | `checkbox-ce-oem.remote-slave` | `checkbox.agent` |
| Frontend | `checkbox-ce-oem` (classic) | `checkbox` snap, devmode |
| Test plan | `com.canonical.contrib::ce-oem-iot-server-24-04-automated` | `com.canonical.certification::client-cert-iot-ubuntucore-24-automated` |
| Deps | docker.io + debs (fwts, stress-ng, …) | `docker` snap |
| sudo | needs `sudo -S -v` priming | passwordless (UC default user) |

## Fill these in
Copy `.local.env.example` to `.local.env` (gitignored) and set `PI_IP`, `PI_USER`,
`PI_PASSWORD`, `WIFI_SSID`, `WIFI_PSK`. IP is pinned by a **router DHCP reservation**.

## Board facts

| Item | Value |
|------|-------|
| OS | Ubuntu Server 24.04 (arm64) |
| Ethernet | `eth0` → `PI_IP` (router reservation) |
| WiFi | `wlan0` (brcmfmac) - creds in launcher |
| BT | yes |
| Agent port | 18871 (`checkbox-ce-oem.remote-slave`) |
| Watchdog | `bcm2835_wdt` |
| RTC | none (`TOTAL_RTC_NUM=0`) |
| Test plan | `com.canonical.contrib::ce-oem-iot-server-24-04-automated` |

## Steps (from repo root, `checkbox-all/`)
```bash
bash raspberry-pi-4/server24.04/run-pi4.sh ping       # 1. reachable?
bash raspberry-pi-4/server24.04/run-pi4.sh provision  # 2. Envicorn (~10-20 min)
bash raspberry-pi-4/server24.04/run-pi4.sh verify     # 3. 18871 OPEN (BEFORE the run only)
bash raspberry-pi-4/server24.04/run-pi4.sh test       # 4. run plan (~30-60 min)
bash raspberry-pi-4/server24.04/run-pi4.sh collect    # 5. reports + .json + totals
```

## Quirks (carried over)
- **Never TCP-probe 18871 during a run** - it kills the session. Ping only mid-run.
- **`sudo -S` + heredoc don't mix** on a fresh flash - prime with `sudo -S -v` first.
- **Power-cycle doesn't clear a checkbox session** - clear the DUT session before re-running.
- **`.json` is bundled in the `.tar.xz`** as `submission.json`; `collect` extracts it.
- Expect `networking/predictable_names` and `miscellanea/efi_boot_mode` to fail
  (Pi uses `eth0`/`wlan0` and U-Boot) - known structural failures.
- Historical baseline for Pi 4 Server 24.04: ~83 passed / ~6 structural failures.
