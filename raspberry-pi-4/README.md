# Raspberry Pi 4 - Checkbox Rapid-Prototyping

Checkbox certification setups for the Raspberry Pi 4, one per OS variant. Both are
host-driven (no SSH): Envicorn provisions the board, the Checkbox controller drives
the run, verification is ping + port only.

| Folder | OS | Agent | Test plan |
|--------|----|-------|-----------|
| [`core24/`](core24/) | Ubuntu Core 24 | `checkbox.agent` | `com.canonical.certification::client-cert-iot-ubuntucore-24-automated` |
| [`server24.04/`](server24.04/) | Ubuntu Server 24.04 | `checkbox-ce-oem.remote-slave` | `com.canonical.contrib::ce-oem-iot-server-24-04-automated` |

Each folder is self-contained: `README.md`, the Envicorn `*-env-setup.yaml`, the
launcher, the `run.sh` helper, `.local.env.example`, and `reports/`.

Same board, two images - flash the one you want, give the board its router-reserved
IP, fill in that folder's `.local.env`, and run.

**Results (done):**
- **Core 24:** 65 passed / 14 failed / 127 cannot_start (full no-skip plan + Docker). `core24/reports/RESULT.md`.
- **Server 24.04:** 79 passed / 10 failed / 209 cannot_start (188 jobs). `server24.04/reports/RESULT.md`.
- Note: WPA WiFi passes on Server but fails on Core 24 (brcmfmac routable-timeout) - Core-specific.
