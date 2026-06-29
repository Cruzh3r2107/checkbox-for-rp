# Xilinx Kria KV260 - Checkbox Rapid-Prototyping

Checkbox certification setups for the Xilinx Kria KV260 (Zynq UltraScale+), one per
OS variant. Both are host-driven (no SSH): Envicorn provisions the board, the
Checkbox controller drives the run, verification is ping + port only.

| Folder | OS | Agent | Test plan |
|--------|----|-------|-----------|
| [`core24/`](core24/) | Ubuntu Core 24 | `checkbox.agent` | `com.canonical.certification::client-cert-iot-ubuntucore-24-automated` |
| [`server24.04/`](server24.04/) | Ubuntu Server 24.04 | `checkbox-ce-oem.remote-slave` | `com.canonical.contrib::ce-oem-iot-server-24-04-automated` |

Each folder is self-contained: `README.md`, the Envicorn `*-env-setup.yaml`, the
launcher, the `run.sh` helper, `.local.env.example`, and `reports/`.

Same board, two images - flash the one you want, give the board its router-reserved
IP, fill in that folder's `.local.env`, and run.

**Results (partial):**
- **Core 24:** 89 passed / 2 failed / 48 cannot_start (~99 of 219 jobs). `core24/reports/RESULT.md`.
- **Server 24.04:** ~148 passed / 4 failed / ~166 cannot_start (~267 of 299 jobs). `server24.04/reports/RESULT.md`.
- Note: neither run completes. The mandatory `power-management/cold-reboot` test wedges the board (it cannot software cold-reboot), and on Core 24 the `snapd/snap-refresh-snapd` test loops. See each folder's known issues.
