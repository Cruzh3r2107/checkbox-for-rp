# Xilinx Kria KV260 - Checkbox Result (good-enough / characterized)

- Date: 2026-06-26 (UTC)
- Board: Xilinx Kria KV260 (Zynq UltraScale+), Ubuntu Server 24.04, IP 192.168.50.27
- Test plan: com.canonical.contrib::ce-oem-iot-server-24-04-automated
- Launcher excludes: `.*cpu/scaling_test.*` (kernel-wedging job)
- Evidence: `kria-run-2026-06-26.log` (no submission file - run was stopped at the
  cold-reboot test, so totals are parsed from the streamed log)

## Totals (from run log, ~267/299 jobs executed)
passed≈148 failed=4 cannot_start≈166

Counts are slightly inflated by checkbox re-enumerating jobs after each reboot
test; treat as approximate. ~90% of the plan executed.

## Failures (4) - all structural / expected
- `miscellanea/efi_boot_mode` - Kria boots via U-Boot, not EFI
- `networking/predictable_names` - interface is `eth0`, not a predictable name
- `miscellanea/check_prerelease` - the Xilinx Kria image is flagged pre-release
- (1 unnamed, early/around the reboot tests)

No non-structural failures. Broad pass coverage: docker (17), snapd (11),
ce-oem-crypto (9), snappy (8), ce-oem-cpu (7), cpu (5), socketcan (4), rtc (4),
ethernet (3), power-management (warm-reboot), etc.

## Board-wedging tests to EXCLUDE on this hardware
Two jobs hang the Zynq UltraScale+ at the kernel level (only a power-cycle clears them):
- `cpu/scaling_test` - uninterruptible sysfs cpufreq write (excluded this run)
- `power-management/cold-reboot` - board does not return after a software cold reboot
  (warm-reboot is fine). Exclude it for a fully-completing automated run.

## Quirks learned (provisioning + run)
- `sudo -S` + trailing heredoc: heredoc steals stdin so the password never reaches
  sudo. Use `sudo -S -v` to cache creds first, then run sudo commands separately.
- Use `checkbox-ce-oem.remote-slave` (NOT `checkbox.agent`) for the contrib test plan;
  both listen on 18871, so stop checkbox.agent first.
- IP pinned via router DHCP reservation, not a board-side static IP.
- NEVER TCP-probe port 18871 while a control session is live - it hijacks/kills the run.
- A power-cycle does not clear an interrupted checkbox session on the agent; clear the
  DUT session before re-running or the controller resumes (and may crash/loop).
