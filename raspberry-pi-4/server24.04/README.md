# Raspberry Pi 4 - Ubuntu Server 24.04

Board-and-OS specific configuration for a Checkbox run on the Raspberry Pi 4 running
Ubuntu Server 24.04.

> The full workflow, host prerequisites, and how to read results are in the
> [main README](../../README.md). This page covers only what is specific to this
> board and OS.

## What is in this folder

| File | Purpose |
|------|---------|
| `run-pi4.sh` | Helper that runs the whole flow for this board (`ping`, `provision`, `verify`, `test`, `collect`). |
| `pi4-server2404-env-setup.yaml` | Envicorn provisioning: `checkbox-ce-oem` (classic) + Docker and debs, manifest, `bcm2835_wdt` watchdog, starts `checkbox-ce-oem.remote-slave`. |
| `launcher-pi4-server2404` | Checkbox launcher: test plan, Wi-Fi credentials, `TOTAL_RTC_NUM`. |
| `.local.env.example` | Copy to `.local.env` (gitignored) and fill in. |
| `reports/` | Collected submission files and `RESULT.md`. |

## Board facts

| Item | Value |
|------|-------|
| OS | Ubuntu Server 24.04 (arm64) |
| Ethernet / Wi-Fi | `eth0` / `wlan0` (brcmfmac) |
| Bluetooth | yes |
| Agent | `checkbox-ce-oem.remote-slave`, port 18871 |
| Watchdog | `bcm2835_wdt` |
| RTC | none (`TOTAL_RTC_NUM=0`) |
| Login | needs a sudo password (Ubuntu Server does not import the SSH key) |
| Test plan | `com.canonical.contrib::ce-oem-iot-server-24-04-automated` |

## Run it

Copy `.local.env.example` to `.local.env` and set `PI_IP`, `PI_USER`,
`PI_PASSWORD`, `WIFI_SSID`, `WIFI_PSK`. Run `ssh-copy-id <PI_USER>@<PI_IP>` once and
make sure the account sudo password is set. Then, from this folder:

```bash
bash run-pi4.sh ping        # board reachable
bash run-pi4.sh provision   # one-time setup
bash run-pi4.sh verify      # agent up on 18871 (before the run only)
bash run-pi4.sh test        # run the plan (30 to 60 min)
bash run-pi4.sh collect     # save reports and print pass and fail
```

## Board-specific notes

- Results land in [reports/RESULT.md](reports/RESULT.md) after `collect`.
- Structural failures that cannot be fixed: `miscellanea/efi_boot_mode` (the Pi
  boots U-Boot) and `networking/predictable_names` (the Pi uses `eth0` and `wlan0`).
- On a fresh flash, provisioning primes sudo with `sudo -S -v` before any heredoc;
  the helper handles this.
