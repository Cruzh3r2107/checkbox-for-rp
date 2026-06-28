# Pi 4 Server 24.04 - Checkbox Result

- Date: 2026-06-27 (UTC)
- Board: Raspberry Pi 4, Ubuntu Server 24.04, IP 192.168.50.48 (user vish)
- Test plan: com.canonical.contrib::ce-oem-iot-server-24-04-automated
- Agent: checkbox-ce-oem.remote-slave
- Submission: submission_2026-06-27T05.07.44.244531  (+ .json)
- Run: ~1 hr, 188/188 jobs, completed cleanly

## Totals
passed=79 failed=10 cannot_start=209 total=298

Best pass count of the Pi variants (UC24 was 65). Near the historical baseline (83/6).

## Failures (10) - all structural or environmental, NO board defects

### Structural (Pi 4 / image) - 3
- `miscellanea/efi_boot_mode` - Pi 4 boots U-Boot, not EFI
- `networking/predictable_names` - interface is `eth0`, not a predictable name
- `watchdog/systemd-config` - RuntimeWatchdogUSec drop-in not honored

### Environmental (lab network) - 7
- `wireless/wireless_connection_open_{ac,bg,n}` (3) - no open WiFi AP in lab
- `bluetooth4/beacon_eddystone_url_hci0` - no EddyStone beacon in lab
- `ethernet/ping_eth0` + `ethernet/ping-with-any-cable-interface` (2) - "no host to
  ping found on eth0"; the ASUS gateway drops ICMP / no pingable neighbor. Not a board issue.
- `ipv6_link_local_address_eth0` - no IPv6 link-local on eth0 (IPv6 not enabled in this setup)

## Server vs Core 24 (same board)
- **WPA WiFi PASSES on Server** (only open-AP fails) - on UC24 the WPA tests failed on the
  brcmfmac 30s routable-timeout. So the WiFi limitation is **Core-specific**, not the board.
- Server pass count 79 vs UC24 65 (Server has docker.io + more working subsystems out of the box).

## Notes
- Provisioning: 25/25 Envicorn actions OK. Auth required `ssh-copy-id` (Server flash doesn't
  import SSO keys like UC console-conf), and the sudo password had to match for Action 1.
- `.json` auto-extracted from the tar.xz by `collect`.
