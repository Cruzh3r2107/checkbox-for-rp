# Checkbox for Rapid Prototyping

Ready-to-use Checkbox test setups for running
hardware certification on IoT boards during **rapid prototyping** - plus the
results we got. Everything runs **from a host machine over the network**; you
never SSH into the board by hand.

The boards here (Raspberry Pi 4, Xilinx Kria) are just the ones **we** tested on.
The workflow is the same for any board - see [Adding a new board](#adding-a-new-board).

A formal, shareable version of this guide can be found here: [Checkbox for RP](https://docs.google.com/document/d/1A7a1jLPTWryTrmzUwztosUKiT7drJmG9XM65saRMdB0/edit?tab=t.0).

> New to Checkbox? Learn it properly first: the
> [Checkbox documentation](https://checkbox.readthedocs.io/) and the
> [Checkbox source on GitHub](https://github.com/canonical/checkbox). This repo is a
> fast, practical path for rapid prototyping, not a replacement for those.

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

1. **Provision** the board with **[Envicorn](https://github.com/canonical/envicorn/tree/main)** (`ceqa-env-setup-tools`) - it applies a
   small YAML over SSH to install Checkbox, write the hardware manifest, load the
   watchdog, and start the agent. (One-time per board.)
2. **Run** the test plan with the controller, pointing at a **launcher** file that
   selects the plan and sets a few environment values.

Verification between the two is only **ping + a port check** - no manual SSH.

---

## We run only the automated tests

Checkbox names its test plans with a suffix that says how they run. The same IoT
certification ships as three plans - `-automated`, `-manual`, and `-stress`. For
Ubuntu Core and Ubuntu Server they look like this:

```
client-cert-iot-ubuntucore-24            (Core)      ce-oem-iot-server-24-04   (Server)
  |- -automated   no human, no test rig  (we use this)   |- -automated   (we use this)
  |- -manual      a person confirms steps (cables, keys)  |- -manual
  |- -stress      long soak / reboot / suspend runs       |- -stress
```

For rapid prototyping we run only the **-automated** plan: it needs no human and no
test rig, so it gives a fast, repeatable baseline. The manual and stress plans are
for full certification, where a person and a wired-up test bench are available.

---

## Which provider / plan, and why

Checkbox's docs are big and the provider names are confusing, so here is the only
part that matters for picking a setup. A **provider** is just a bundle of test
jobs + test plans. Two matter:

| Provider | Ships in | Gives you | Test descriptions |
|----------|----------|-----------|-------------------|
| [`com.canonical.certification`](https://github.com/canonical/checkbox) | the `checkbox` snap (+ `checkbox24` runtime) | the standard IoT/Core certification plans | [programmes docs](https://certification.canonical.com/docs/programmes/) |
| [`com.canonical.contrib`](https://github.com/canonical/checkbox-ce-oem) | the `checkbox-ce-oem` **classic** snap | extra OEM/Server IoT plans, on top of certification | [programmes docs](https://certification.canonical.com/docs/programmes/) |

**Pick by OS.** The board's OS decides the provider, agent, and plan. This is the
only choice that matters:

| Board OS | Snap on DUT | Agent | Test plan |
|----------|-------------|-------|-----------|
| **Ubuntu Core** | `checkbox` (devmode) | `checkbox.agent` | `client-cert-iot-ubuntucore-24-automated` |
| **Ubuntu Server** | `checkbox-ce-oem` (classic) | `checkbox-ce-oem.remote-slave` | `ce-oem-iot-server-24-04-automated` |

The host **controller is always `checkbox-ce-oem.checkbox-cli control`** for both.

---

## Using this repo


To run Checkbox for rapid-prototyping images on IoT devices you need **3 files**.
Create a folder for your board and OS (for example `my-board/server24.04/`). Clean
starting templates for all three live in [`template/`](template/); copy them in and
fill them out.

| # | File | What it is | Start from |
|---|------|-----------|-----------|
| 1 | `.local.env` | Your board's IP, login, and WiFi creds. **Gitignored** - secrets never get committed. | [`template/.local.env.example`](template/.local.env.example) |
| 2 | `*-env-setup.yaml` | The **Envicorn** provisioning recipe: which snaps, the hardware manifest, the watchdog, start the agent. | Server: [`template/server-env-setup.yaml`](template/server-env-setup.yaml) <br> Core: [`template/core-env-setup.yaml`](template/core-env-setup.yaml) |
| 3 | `launcher-*` | Picks the test plan and sets run options (WiFi creds, RTC count). | Server: [`template/server-launcher`](template/server-launcher) <br> Core: [`template/core-launcher`](template/core-launcher) |

For a full real-world Server example see: [server2404_env_setup.yaml](https://github.com/canonical/ce-oem-dut-checkbox-configuration/blob/main/project/koto/server2404_env_setup.yaml).

> **Why a fixed IP?** Some tests reboot the board mid-run. Pin the IP with a
> **router DHCP reservation** so the same address survives the reboot and the run
> does not lose the board.

---

## Prerequisites for host and target

**Host** (same for both targets): install the controller and Envicorn snaps.

```bash
sudo snap install checkbox-ce-oem --classic
sudo snap install ceqa-env-setup-tools --classic
```

The host `checkbox24` snap must also be **enabled**, or the controller fails with
*"no wrapper_common_classic found"*.

**Target:** flashed with the OS, booted, on the network, and reachable at its reserved
IP. Its Checkbox snaps are installed for you during provisioning. The login differs by
OS:

- Target is Server: Ubuntu Server does **not** import your SSH key, so add it once with
  `ssh-copy-id <USER>@<DEVICE_IP>`, and make sure the account's sudo password is set
  (provisioning needs it).
- Target is Core: console-conf **imports your SSH key**, so key auth works out of the
  box, and the default user has **passwordless sudo**. No `ssh-copy-id` and no sudo
  password are needed.

---

## How to run it

### Option A: doing it manually

1. **Provision with Envicorn.** Envicorn applies the YAML of actions over SSH (see
   [`ceqa-env-setup-tools`](https://snapcraft.io/ceqa-env-setup-tools)). Point it at
   your OS's env-setup file.

   Target is Server:

   ```bash
   ceqa-env-setup-tools.test-env-setup setup \
     -f <your-server-env-setup>.yaml \
     --remote-ip <DEVICE_IP> --username <USER> --password <PASSWORD>
   ```

   Target is Core (no `--password`; Core authenticates with your imported SSH key):

   ```bash
   ceqa-env-setup-tools.test-env-setup setup \
     -f <your-core-env-setup>.yaml \
     --remote-ip <DEVICE_IP> --username <USER>
   ```

2. **Check the agent is up** (only before the run, never during it):

   ```bash
   ping -c2 <DEVICE_IP>
   (echo > /dev/tcp/<DEVICE_IP>/18871) && echo "agent up"
   ```

3. **Run the test plan.** The controller (`checkbox-ce-oem.checkbox-cli control`) is the
   same for both; point it at your OS's launcher. To write or customise a launcher, see
   the [Checkbox launcher reference](https://checkbox.readthedocs.io/en/latest/launcher.html).

   Target is Server:

   ```bash
   checkbox-ce-oem.checkbox-cli control <DEVICE_IP> <your-server-launcher>
   ```

   Target is Core:

   ```bash
   checkbox-ce-oem.checkbox-cli control <DEVICE_IP> <your-core-launcher>
   ```

4. **Collect the results.** Submission files land in `~/.local/share/checkbox-ng/`. The
   full JSON is bundled inside the `.tar.xz` as `submission.json`:

   ```bash
   tar xJf ~/.local/share/checkbox-ng/submission_*.tar.xz submission.json
   ```

### Option B: use the helper script

The helper does all of the above in one place:

```bash
bash <board>/<os>/run.sh ping        # board reachable?
bash <board>/<os>/run.sh provision   # install + configure Checkbox (once)
bash <board>/<os>/run.sh verify      # agent up on 18871 (BEFORE the run only)
bash <board>/<os>/run.sh test        # run the plan (streams; 30 to 60 min)
bash <board>/<os>/run.sh collect     # save reports + extract json + print pass/fail
```
---

## Output: read the results

`collect` prints a single line and saves the full reports into the board's
`reports/` folder:

```
passed=65 failed=14 cannot_start=127 total=206
```

Read it like this:

| Result | Meaning | Action |
|--------|---------|--------|
| **passed** | Hardware works on this image. | Nothing. |
| **cannot_start** | Test for hardware the board does not have, gated off by the manifest. **Large and expected** on a bare board. | Nothing - not a failure. |
| **failed** | Needs a look. Sort it (below). | Triage. |

**Every failure is one of three kinds.** Each `reports/RESULT.md` sorts them this way:

- **Structural** - the board simply cannot pass it (e.g. the Pi boots U-Boot, not
  EFI). Not fixable from provisioning.
- **Environmental** - the lab lacks something the test needs (no open WiFi AP, no
  EddyStone beacon, no ping target). Not a board defect.
- **Real** - a genuine hardware or image issue worth investigating.

> A bare-board run with a high `cannot_start` and a handful of structural /
> environmental failures is a **healthy baseline**, not a problem.

The saved reports in `reports/`:

| File | Use |
|------|-----|
| `RESULT.md` | Human summary with failures pre-sorted. **Read this first.** |
| `submission_*.json` | Full machine-readable results (extracted from the tar). |
| `submission_*.html` | Browsable report. |
| `submission_*.junit.xml` | CI-friendly pass/fail. |
| `submission_*.tar.xz` | Everything, raw. |

---

## Known gotchas

- **Never** open port 18871 (TCP) while a test is running - the agent treats it as a
  new controller and **kills your run**. Use `ping` during a run; only `verify` before.
- A **power-cycle does not clear** an interrupted Checkbox session on the board - clear
  it (stop agent, remove session dirs, start agent) or the next run resumes the old one.
- Some tests **reboot the board on purpose** (snapd update tests) - that's normal and
  it recovers. A few tests can't complete without a physical power-cycle on certain
  hardware (e.g. cold-reboot / cpu-scaling on the Kria) - those are excluded and
  flagged in the relevant folder's README.

## Adding a new board

The workflow does not change, only a few board facts do. See
[docs/adding-a-new-board.md](docs/adding-a-new-board.md).
