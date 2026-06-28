# Checkbox for Rapid Prototyping

Ready-to-use [Checkbox](https://checkbox.readthedocs.io/) test setups for running
hardware certification on IoT boards during **rapid prototyping** - plus the
results we got. Everything runs **from a host machine over the network**; you
never SSH into the board by hand.

The boards here (Raspberry Pi 4, Xilinx Kria) are just the ones **we** tested on.
The workflow is the same for any board - see [Adding a new board](#adding-a-new-board).

---

## How Checkbox works here (the short version)

Checkbox runs in **remote mode**: a **controller** on your host drives an **agent**
on the device under test (DUT).

```
  HOST (controller)                          DUT (agent, port 18871)
  checkbox-ce-oem.checkbox-cli control  --->  runs the test jobs locally
        reads a "launcher" file                 streams results back
```

We split every board into **two stages**:

1. **Provision** the board with **Envicorn** (`ceqa-env-setup-tools`) - it applies a
   small YAML over SSH to install Checkbox, write the hardware manifest, load the
   watchdog, and start the agent. (One-time per board.)
2. **Run** the test plan with the controller, pointing at a **launcher** file that
   selects the plan and sets a few environment values.

Verification between the two is only **ping + a port check** - no manual SSH.

## Which provider / plan, and why

Checkbox's docs are big and the provider names are confusing, so here is the only
part that matters for picking a setup. A **provider** is just a bundle of test
jobs + test plans. Two matter:

| Provider | Ships in | Gives you |
|----------|----------|-----------|
| `com.canonical.certification` | the `checkbox` snap (+ `checkbox24` runtime) | the standard IoT/Core certification plans |
| `com.canonical.contrib` | the `checkbox-ce-oem` **classic** snap | extra OEM/Server IoT plans, on top of certification |

The board's **OS decides which one you can use**:

- **Ubuntu Core** → only strict/devmode snaps install (no classic), so you use the
  **`checkbox` snap (devmode)**, agent **`checkbox.agent`**, plan
  **`client-cert-iot-ubuntucore-24-automated`** (certification provider). This is
  the standard Canonical way to run Checkbox on Core - not a workaround.
- **Ubuntu Server** → classic snaps install, so you use **`checkbox-ce-oem`**, agent
  **`checkbox-ce-oem.remote-slave`**, plan **`ce-oem-iot-server-24-04-automated`**
  (contrib provider) - the fuller OEM IoT server plan.

The host **controller is always `checkbox-ce-oem.checkbox-cli control`** for both.

Docs: [Checkbox](https://checkbox.readthedocs.io/) ·
[Checkbox on GitHub](https://github.com/canonical/checkbox) ·
[checkbox snap](https://snapcraft.io/checkbox)

---

## Using this repo

1. Pick your board folder, then the OS subfolder (e.g. `raspberry-pi-4/core24/`).
2. Read that folder's short README and copy `.local.env.example` → `.local.env`
   (gitignored) with your board's IP, login, and any WiFi creds.
3. Run the helper, in order:

   ```bash
   bash <board>/<os>/run-*.sh ping        # board reachable?
   bash <board>/<os>/run-*.sh provision   # install + configure Checkbox (once)
   bash <board>/<os>/run-*.sh verify       # agent up on 18871 (BEFORE the run only)
   bash <board>/<os>/run-*.sh test         # run the plan (streams; 30-60 min)
   bash <board>/<os>/run-*.sh collect      # save reports + print pass/fail
   ```

Results land in that folder's `reports/` (`RESULT.md` + `junit.xml` are committed;
the raw JSON/HTML/tar are gitignored - regenerate with `collect`).

### Host prerequisites
- Host and board on the **same network**; give the board a **fixed IP via a router
  DHCP reservation** (so it survives the reboots that some tests trigger).
- Host snaps: `checkbox-ce-oem` (controller) and `ceqa-env-setup-tools` (Envicorn).
  The host's `checkbox24` snap must be **enabled** or the controller fails with
  *"no wrapper_common_classic found"*.

---

## Adding a new board

The workflow doesn't change - only a few board facts do. For a new board, set:

- **Agent + plan + deps** by OS (see the table above).
- **Watchdog kernel module** (e.g. `bcm2835_wdt` on Pi, `cadence_wdt` on Kria).
- **Has WiFi / BT / RTC?** → manifest values + `TOTAL_RTC_NUM` in the launcher.
- **Machine manifest** - declare what hardware exists; absent hardware is correctly
  skipped (shows as `cannot_start`, which is expected, not a failure).

Copy the closest existing OS folder, edit those values, and run.

## Reading results

- **`cannot_start` is expected and large** on a bare board - those are tests for
  hardware the board doesn't have (gated off by the manifest). Not failures.
- **Failures** fall into: *structural* (e.g. Pi boots U-Boot not EFI), *environmental*
  (no open WiFi AP / no ping target in the lab), or *real* (worth investigating).
  Each `reports/RESULT.md` categorizes them.

## Known gotchas (save yourself the pain)

- **Never** open port 18871 (TCP) while a test is running - the agent treats it as a
  new controller and **kills your run**. Use `ping` during a run; only `verify` before.
- A **power-cycle does not clear** an interrupted Checkbox session on the board - clear
  it (stop agent, remove session dirs, start agent) or the next run resumes the old one.
- Some tests **reboot the board on purpose** (snapd update tests) - that's normal and
  it recovers. A few tests can't complete without a physical power-cycle on certain
  hardware (e.g. cold-reboot / cpu-scaling on the Kria) - those are excluded and
  flagged in the relevant folder's README.

## Status

| Board | Ubuntu Core 24 | Ubuntu Server 24.04 |
|-------|----------------|---------------------|
| Raspberry Pi 4 | ✅ 65 / 14 / 127 | ✅ 79 / 10 / 209 |
| Xilinx Kria KV260 | ⏳ in progress | ☑️ partial (documented) |

*(passed / failed / cannot_start)*
