# Xilinx Kria KV260 - Ubuntu Core 24 - Checkbox Result (partial)

- Date: 2026-06-27 (UTC)
- Board: Xilinx Kria KV260 (Zynq UltraScale+), Ubuntu Core 24, IP 192.168.50.27
- Test plan: com.canonical.certification::client-cert-iot-ubuntucore-24-automated
- Agent: checkbox.agent
- Evidence: kria-core24-run-2026-06-27.log (no submission file, see below)

## Totals (partial, ~99 of 219 jobs ran)
passed=89 failed=2 cannot_start=48

The run could not complete (see blockers below), so these are the counts from the
jobs that ran before the run stopped. cannot_start would be higher in a full run
(more manifest-gated jobs come later).

## Failures (2) - both structural
- `image/model-grade` - dev/devmode image, not a graded "secured" model.
- `networking/predictable_names` - interface is `eth0`, not a predictable name.

## Why the run cannot complete on this board (two mandatory blockers)
The automated plan forces two tests that this board cannot get through, and neither
can be excluded by the launcher (mandatory jobs):

1. `power-management/cold-reboot` - the Kria cannot perform a software cold reboot
   (it never returns; only a physical power-cycle recovers it). Confirmed on both
   Core 24 and Server 24.04, so it is a board/firmware limitation, not an OS issue.

2. `snapd/snap-refresh-snapd-snapd-to-stable-rev` - on the `amd-kria` gadget snap,
   this refresh test reboots repeatedly without settling, so Checkbox re-runs it
   after every reboot (an endless reboot loop, ~80 reconnects). This is a checkbox
   and snapd-gadget interaction bug specific to this board (the same test completes
   on the Pi).

So a fresh run wedges at cold-reboot, and a resumed run loops at snap-refresh-snapd.
This is the same outcome as the Kria Server run: a documented partial.

## Notes
- Provisioning: 7/7 Envicorn actions OK (checkbox devmode + docker, manifest, watchdog).
- File an upstream Checkbox issue for the snap-refresh-snapd reboot loop on the
  amd-kria gadget.
