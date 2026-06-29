# Xilinx Kria KV260 - Ubuntu Core 24

Board-and-OS specific configuration for a Checkbox run on the Xilinx Kria KV260
(Zynq UltraScale+) running Ubuntu Core 24.

> The full workflow, host prerequisites, and how to read results are in the
> [main README](../../README.md). This page covers only what is specific to this
> board and OS.

## What is in this folder

| File | Purpose |
|------|---------|
| `run-kria.sh` | Helper that runs the whole flow for this board (`ping`, `provision`, `verify`, `test`, `collect`). |
| `kria-core24-env-setup.yaml` | Envicorn provisioning: `checkbox` (devmode) + `docker`, manifest, `cadence_wdt` watchdog, starts `checkbox.agent`. |
| `launcher-kria-kv260-core24` | Checkbox launcher: test plan and `TOTAL_RTC_NUM`. |
| `.local.env.example` | Copy to `.local.env` (gitignored) and fill in. |
| `reports/` | Collected `RESULT.md` and the run log. |

## Board facts

| Item | Value |
|------|-------|
| OS | Ubuntu Core 24 (arm64) |
| Ethernet | `eth0` (router DHCP reservation) |
| Wi-Fi / Bluetooth | none (headless board) |
| Agent | `checkbox.agent`, port 18871 |
| Watchdog | `cadence_wdt` (fallback `zynq_wdt`) |
| RTC | 1 (`TOTAL_RTC_NUM=1`) |
| Login | passwordless sudo (Ubuntu Core default user) |
| Test plan | `com.canonical.certification::client-cert-iot-ubuntucore-24-automated` |

## Run it

Copy `.local.env.example` to `.local.env` and set `KRIA_IP`, `KRIA_USER`,
`KRIA_PASSWORD` (no Wi-Fi on this board). Then, from this folder:

```bash
bash run-kria.sh ping        # board reachable
bash run-kria.sh provision   # one-time setup
bash run-kria.sh verify      # agent up on 18871 (before the run only)
bash run-kria.sh test        # run the plan (30 to 60 min)
bash run-kria.sh collect     # save reports and print pass and fail
```

## Board-specific notes

- This board cannot complete the automated plan. Two mandatory jobs cannot be
  excluded by the launcher: `power-management/cold-reboot` wedges the board (the
  Kria cannot software cold-reboot; only a physical power-cycle recovers it), and
  `snapd/snap-refresh-snapd` loops on the `amd-kria` gadget snap.
- Documented partial result: 89 passed / 2 failed / 48 cannot_start. See
  [reports/RESULT.md](reports/RESULT.md).
- Structural failures that cannot be fixed: `miscellanea/efi_boot_mode` (U-Boot),
  `networking/predictable_names` (`eth0`), and `image/model-grade` (devmode image).
