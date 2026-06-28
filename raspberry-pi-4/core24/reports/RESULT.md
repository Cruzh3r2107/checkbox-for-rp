# Pi 4 UC24 - Checkbox Result (final)

- Date: 2026-06-26 (UTC)
- Board: Raspberry Pi 4, Ubuntu Core 24, IP 192.168.50.47
- Test plan: com.canonical.certification::client-cert-iot-ubuntucore-24-automated
- Launcher excludes: `.*snapd/.*(refresh|revert).*` (reboot-looping structural tests)
- Submission: submission_2026-06-26T15.24.28.538709
- Run time: ~39 min, 99/99 jobs, clean (no reboot loop)

## Totals (FINAL - no-skip full plan, with Docker)
passed=65 failed=14 cannot_start=127 total=206
Submission: submission_2026-06-26T23.01.31.167921

Progression:
- Run 1 (snapd included, no docker):   48 / 11 / 147 (206)
- Clean (snapd excluded):              39 / 10 / 133 (182)
- + Docker snap:                       59 / 10 / 113 (182)  <-- +20 docker passes
- NO-SKIP full plan + Docker (final):  65 / 14 / 127 (206)  <-- canonical result

The final run runs the COMPLETE plan, nothing excluded. snapd tests ran with 4
reboots / 6 reconnects and the run completed cleanly (no loop - the earlier loop
was a stale-session-resume artifact, not the tests). snapd family contributed
9 pass / 14 cannot_start / 1 fail, plus 3 snappy structural fails.

## The 14 failures (all understood)
- snapd/snappy structural (4): snap-verify-after-refresh-kernel, snappy/snap-remove,
  snappy/snap-reupdate-automated, snappy/snap-revert-automated - need beta/candidate channels.
- Bluetooth (3): detect-output + 2 EddyStone beacon (no beacon in lab).
- watchdog/systemd-config (1): UC ignores RuntimeWatchdogUSec drop-in.
- wireless (6): 3 WPA (brcmfmac routable-timeout) + 3 open (no open AP).

## Failures

### Expected - environmental (5)
- `wireless/wireless_connection_open_{ac,bg,n}_np_wlan0` - no open WiFi AP in lab
- `bluetooth4/beacon_eddystone_url_hci0` + after-suspend variant - no EddyStone beacon in lab

### Genuine UC24-Pi platform limitations (5) - NOT fixable from provisioning
- `watchdog/systemd-config` - RuntimeWatchdogUSec stays 0 after a clean boot;
  Ubuntu Core does not apply `/etc/systemd/system.conf.d/*.conf` for the hardware
  watchdog. Would need the gadget snap / kernel cmdline. Out of scope for the host-side flow.
- `bluetooth/detect-output` - "BT hardware not available"; the BT adapter does not
  enumerate on this UC24 Pi image (rfkill-unblock / bluez start / power-on don't help
  because no hci device appears). Image/enablement gap.
- `wireless/wireless_connection_wpa_{ac,bg,n}_np_wlan0` - the test runs (manages its
  own netplan, brcmfmac driver) but the in-test WPA association fails. WiFi itself works
  (wlan0 gets a DHCP lease via netplan), so this is a driver/timing issue inside the test,
  not a credential problem.

## Fixes applied this run (and outcome)
- Router DHCP reservation instead of board-side static IP - works, IP stable across reboot.
- Dropped `snap refresh` from provisioning - removed mid-run reboot from provisioning.
- Excluded snapd refresh/revert tests - removed the resume reboot-loop.
- watchdog `daemon-reexec` + BT `rfkill/start/power-on` - applied but INEFFECTIVE
  (the two failures above are platform-level, confirmed stable across a clean run).
- **Docker snap added to provisioning - EFFECTIVE: +20 passes** (all docker jobs
  moved from cannot_start to passed). This is the single biggest win.
- WiFi pre-warm (rfkill/modprobe/scan) - INEFFECTIVE; the wireless failures are the
  test's hardcoded 30s routable-wait + brcmfmac reaching only "degraded" state,
  not a firmware-warmth or credential issue.

## Operational quirks learned (see also xilinx-kria/)
- NEVER TCP-probe agent port 18871 while a control session is live - the agent treats the
  new connection as a new controller and forcefully disconnects the running session. Probe
  only before a run; use ping (ICMP) during a run.
- snapd refresh/revert tests reboot the board and, on resume, replay in an endless loop;
  exclude them for a stable automated run.
- A power-cycle does NOT clear an interrupted checkbox session on the agent; the controller
  will try to resume (and may crash). Clear sessions on the DUT, then re-run.
