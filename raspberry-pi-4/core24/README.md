# Raspberry Pi 4 - Ubuntu Core 24

Board-and-OS specific configuration for a Checkbox run on the Raspberry Pi 4 running
Ubuntu Core 24.

> The full workflow, host prerequisites, and how to read results are in the
> [main README](../../README.md). This page covers only what is specific to this
> board and OS.

## What is in this folder

| File | Purpose |
|------|---------|
| `run-pi4.sh` | Helper that runs the whole flow for this board (`ping`, `provision`, `verify`, `test`, `collect`). |
| `pi4-uc24-env-setup.yaml` | Envicorn provisioning: `checkbox` (devmode) + `bluez`, manifest, `bcm2835_wdt` watchdog, starts `checkbox.agent`. |
| `launcher-pi4-uc24` | Checkbox launcher: test plan, Wi-Fi credentials, `TOTAL_RTC_NUM`. |
| `.local.env.example` | Copy to `.local.env` (gitignored) and fill in. |
| `reports/` | Collected submission files and `RESULT.md`. |

## Board facts

| Item | Value |
|------|-------|
| OS | Ubuntu Core 24 (arm64) |
| Ethernet / Wi-Fi | `end0` / `wlan0` (brcmfmac, AC, no ax) |
| Bluetooth | yes |
| Agent | `checkbox.agent`, port 18871 |
| Watchdog | `bcm2835_wdt` |
| RTC | none (`TOTAL_RTC_NUM=0`) |
| Login | passwordless sudo (Ubuntu Core default user) |
| Test plan | `com.canonical.certification::client-cert-iot-ubuntucore-24-automated` |

## Run it

Copy `.local.env.example` to `.local.env` and set `PI_IP`, `PI_USER`,
`PI_PASSWORD`, `WIFI_SSID`, `WIFI_PSK`. Then, from this folder:

```bash
bash run-pi4.sh ping        # board reachable
bash run-pi4.sh provision   # one-time setup
bash run-pi4.sh verify      # agent up on 18871 (before the run only)
bash run-pi4.sh test        # run the plan (30 to 60 min)
bash run-pi4.sh collect     # save reports and print pass and fail
```

## Board-specific notes

- Result on this board: 65 passed / 14 failed / 127 cannot_start (full plan with
  Docker). See [reports/RESULT.md](reports/RESULT.md).
- WPA Wi-Fi fails here but passes on Server: a Core-specific brcmfmac
  routable-timeout, not a credential problem.
- `snap refresh` is intentionally skipped in provisioning; on Core 24 it triggers
  kernel and snapd reboots that break provisioning.
- Structural failures that cannot be fixed: `miscellanea/efi_boot_mode` (the Pi
  boots U-Boot), and the open-Wi-Fi and EddyStone-beacon tests (not present in the
  lab).
