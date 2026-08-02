# Luna Gaming Mode and DS5 Bridge wake

## Scope

`luna` uses Jovian NixOS to boot directly into Steam Gaming Mode. Steam's **Switch to Desktop** action starts the existing Sway session. The repository's token-based Everforest theme remains responsible for Sway, Waybar, Wofi, swaylock, and shell colors; it does not modify Steam Gaming Mode.

The Raspberry Pi Pico running DS5 Bridge can wake the machine through USB when the firmware advertises USB remote wakeup and the motherboard keeps the selected USB path powered during suspend.

## Firmware and hardware prerequisites

- Use the current DS5 Bridge 1.7 firmware line with remote-wakeup support.
- Pair the DualSense controller with the Pico and connect the Pico directly to a motherboard USB port for initial testing.
- In firmware setup, enable USB wake or resume by USB device.
- Disable ErP/EuP settings that remove USB power during suspend.
- Test without an unpowered USB hub first.

## Deploy

After updating the flake lock, build Luna before switching:

```console
nix flake lock
nix build .#nixosConfigurations.luna.config.system.build.toplevel
sudo nixos-rebuild test --flake .#luna
```

A successful test should boot the Jovian session through SDDM. The normal session flow is:

1. Boot into Steam Gaming Mode.
2. Choose **Power > Switch to Desktop** to enter Sway.
3. Log out of Sway to return to Gaming Mode.

## Check the bridge wake path

Run:

```console
ds5-bridge-wakeup-status
```

The output should show:

- one of the supported USB identities (`054c:0ce6`, `054c:09cc`, or `1209:db05`);
- `remote wakeup advertised` in the USB descriptor check;
- `enabled` for the bridge and applicable parent USB/PCI wake nodes;
- the currently selected kernel suspend mode in `/sys/power/mem_sleep`.

Reapply the policy manually when troubleshooting:

```console
sudo ds5-bridge-wakeup enable
```

The same command runs automatically at boot, when a supported bridge identity appears through udev, and immediately before suspend.

## Test suspend and wake

Start with the firmware/kernel-selected suspend mode:

```console
systemctl suspend
```

After the machine is asleep, turn on or reconnect the DualSense controller with the PS button. Confirm that Luna resumes and the controller is usable in Gaming Mode.

If USB wake fails, record the current modes:

```console
cat /sys/power/mem_sleep
```

Test `s2idle` for one boot by adding `mem_sleep_default=s2idle` at the bootloader command line. If that solves wake, set:

```nix
hardware_ds5_bridge_wakeup.suspendMode = "s2idle";
```

Do not make this permanent before checking standby power use. `deep` often uses less power but gives platform firmware more control over which USB devices can wake the machine.

## Logs

After a failed suspend or wake attempt:

```console
journalctl -b -u ds5-bridge-wakeup.service
journalctl -b -1 -k | grep -Ei 'suspend|resume|wakeup|xhci|usb'
journalctl -b -1 | grep -Ei 'gamescope|steam|sddm|jovian'
```

Also check `/proc/acpi/wakeup`. The diagnostic command reports entries whose names resemble USB/xHCI controllers, but it deliberately does not toggle them because writing that file toggles state rather than setting it idempotently.

## Remote recovery over SSH

Luna enables the same key-only OpenSSH policy and administrator public keys as `icarus`. Password and keyboard-interactive authentication are disabled, root login is not permitted, and OpenSSH refuses connections whose IPv4 source address is outside `10.0.0.0/8`. Luna's workstation firewall remains disabled; the SSH restriction does not enable or otherwise alter it. On hosts that already use the NixOS nftables firewall, the module also applies the same source restriction at the packet-filter layer.

From a machine holding the matching private key, connect as `mhr` using whichever Luna address is reachable:

```console
ssh mhr@luna
# or
ssh mhr@<luna-ip-address>
```

Confirm the rescue path before testing Gaming Mode or suspend changes:

```console
systemctl is-active sshd
ss -lnt | grep ':22'
```

## Recovery

To stop booting directly into Gaming Mode while retaining Jovian packages and restore the repository's themed SDDM greeter:

```nix
role_jovian_gaming.autoStart = false;
desktop_sddm.enable = true;
```

To disable the complete Jovian role:

```nix
role_jovian_gaming.enable = false;
desktop_sddm.enable = true;
```

To disable only controller wake:

```nix
hardware_ds5_bridge_wakeup.enable = false;
```
