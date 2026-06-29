# Xilinx Kria KV260 - Ubuntu Server 24.04

Board-and-OS specific configuration for a Checkbox run on the Xilinx Kria KV260
(Zynq UltraScale+) running Ubuntu Server 24.04.

> The full workflow, host prerequisites, and how to read results are in the
> [main README](../../README.md). This page covers only what is specific to this
> board and OS.

## What is in this folder

| File | Purpose |
|------|---------|
| `run.sh` | Generic helper (the same run.sh in every folder; canonical copy in template/run.sh) that runs the whole flow (`ping`, `provision`, `verify`, `test`, `collect`). |
| `kria-server2404-env-setup.yaml` | Envicorn provisioning: `checkbox-ce-oem` (classic) + Docker and debs, manifest, `cadence_wdt` watchdog, starts `checkbox-ce-oem.remote-slave`. |
| `launcher-kria-kv260-server2404` | Checkbox launcher: test plan and `TOTAL_RTC_NUM`. |
| `.local.env.example` | Copy to `.local.env` (gitignored) and fill in. |
| `reports/` | Collected `RESULT.md` and the run log. |

## Board facts

| Item | Value |
|------|-------|
| OS | Ubuntu Server 24.04 (arm64) |
| Ethernet | `eth0` (router DHCP reservation) |
| Wi-Fi / Bluetooth | none (headless board) |
| Agent | `checkbox-ce-oem.remote-slave`, port 18871 |
| Watchdog | `cadence_wdt` (fallback `zynq_wdt`) |
| RTC | 1 (`TOTAL_RTC_NUM=1`) |
| Login | needs a sudo password (Ubuntu Server does not import the SSH key) |
| Test plan | `com.canonical.contrib::ce-oem-iot-server-24-04-automated` |

## Run it

Copy `.local.env.example` to `.local.env` and set `DEVICE_IP`, `DEVICE_USER`,
`DEVICE_PASSWORD` (no Wi-Fi on this board). Run `ssh-copy-id <DEVICE_USER>@<DEVICE_IP>`
once and make sure the account sudo password is set. Then, from this folder:

```bash
bash run.sh ping        # board reachable
bash run.sh provision   # one-time setup
bash run.sh verify      # agent up on 18871 (before the run only)
bash run.sh test        # run the plan (30 to 60 min)
bash run.sh collect     # save reports and print pass and fail
```

## Board-specific notes

- This board cannot complete the automated plan. Two mandatory jobs cannot be
  excluded by the launcher: `power-management/cold-reboot` wedges the board (the
  Kria cannot software cold-reboot), and `cpu/scaling_test` hangs it at the kernel
  level on an uninterruptible cpufreq write. Only a physical power-cycle recovers it.
- Documented partial result: ~148 passed / 4 failed / ~166 cannot_start. See
  [reports/RESULT.md](reports/RESULT.md).
- Structural failures that cannot be fixed: `miscellanea/efi_boot_mode` (U-Boot)
  and `networking/predictable_names` (`eth0`).
