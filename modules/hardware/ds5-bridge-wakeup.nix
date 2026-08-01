{
  config,
  lib,
  pkgs,
  ...
}: let
  id = "hardware_ds5_bridge_wakeup";
  cfg = config.${id};

  wakeTool = pkgs.writeShellApplication {
    name = "ds5-bridge-wakeup";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      usbutils
    ];
    text = ''
      set -euo pipefail

      enable_parents="${
        if cfg.enableParentWakePath
        then "1"
        else "0"
      }"
      bridge_count=0

      is_supported() {
        case "$1:$2" in
          054c:0ce6 | 054c:09cc | 1209:db05) return 0 ;;
          *) return 1 ;;
        esac
      }

      device_name() {
        case "$1:$2" in
          054c:0ce6) printf '%s' 'DualSense persona' ;;
          054c:09cc) printf '%s' 'DualShock 4 persona' ;;
          1209:db05) printf '%s' 'Xbox 360 persona' ;;
          *) printf '%s' 'unknown persona' ;;
        esac
      }

      for_each_bridge() {
        local action="$1"
        local device vid pid

        for device in /sys/bus/usb/devices/*; do
          [ -r "$device/idVendor" ] || continue
          [ -r "$device/idProduct" ] || continue

          vid="$(tr '[:upper:]' '[:lower:]' <"$device/idVendor")"
          pid="$(tr '[:upper:]' '[:lower:]' <"$device/idProduct")"
          is_supported "$vid" "$pid" || continue

          case "$action" in
            enable)
              enable_bridge "$device" "$vid" "$pid"
              ;;
            status)
              bridge_count=$((bridge_count + 1))
              show_wakeup_path "$device" "$vid" "$pid"
              ;;
          esac
        done
      }

      enable_wakeup_file() {
        local node="$1"
        local wakeup="$node/power/wakeup"

        [ -e "$wakeup" ] || return 0
        if [ -w "$wakeup" ]; then
          printf 'enabled' >"$wakeup"
          printf 'enabled wakeup: %s\n' "$node"
        else
          printf 'wakeup is not writable: %s\n' "$node" >&2
        fi
      }

      enable_bridge() {
        local device="$1"
        local vid="$2"
        local pid="$3"
        local node parent

        printf 'DS5 Bridge %s (%s:%s)\n' "$(device_name "$vid" "$pid")" "$vid" "$pid"
        node="$(realpath -e "$device")"

        while [[ "$node" == /sys/devices/* ]]; do
          enable_wakeup_file "$node"
          [ "$enable_parents" = "1" ] || break

          parent="$(dirname "$node")"
          [ "$parent" != "$node" ] || break
          node="$parent"
        done
      }

      show_wakeup_path() {
        local device="$1"
        local vid="$2"
        local pid="$3"
        local node parent value attributes

        printf 'DS5 Bridge %s\n' "$(device_name "$vid" "$pid")"
        printf '  USB ID: %s:%s\n' "$vid" "$pid"
        printf '  Sysfs device: %s\n' "$(realpath -e "$device")"

        if [ -r "$device/manufacturer" ]; then
          printf '  Manufacturer: %s\n' "$(<"$device/manufacturer")"
        fi
        if [ -r "$device/product" ]; then
          printf '  Product: %s\n' "$(<"$device/product")"
        fi
        if [ -r "$device/bcdDevice" ]; then
          printf '  bcdDevice: %s\n' "$(<"$device/bcdDevice")"
        fi

        if [ -r "$device/bmAttributes" ]; then
          attributes="$(<"$device/bmAttributes")"
          attributes="''${attributes#0x}"
          if (( (16#$attributes & 0x20) != 0 )); then
            printf '  USB descriptor: remote wakeup advertised (bmAttributes=%s)\n' "$attributes"
          else
            printf '  USB descriptor: remote wakeup not advertised (bmAttributes=%s)\n' "$attributes"
          fi
        elif lsusb -v -d "$vid:$pid" 2>/dev/null | grep 'Remote Wakeup' >/dev/null; then
          printf '  USB descriptor: remote wakeup advertised\n'
        else
          printf '  USB descriptor: remote wakeup could not be verified\n'
        fi

        printf '  Wake path:\n'
        node="$(realpath -e "$device")"
        while [[ "$node" == /sys/devices/* ]]; do
          if [ -r "$node/power/wakeup" ]; then
            value="$(<"$node/power/wakeup")"
            printf '    %-10s %s\n' "$value" "$node"
          fi

          parent="$(dirname "$node")"
          [ "$parent" != "$node" ] || break
          node="$parent"
        done
      }

      show_status() {
        bridge_count=0
        for_each_bridge status
        if [ "$bridge_count" -eq 0 ]; then
          printf 'No supported DS5 Bridge USB persona is currently connected.\n' >&2
          return 1
        fi

        if [ -r /sys/power/mem_sleep ]; then
          printf '\nKernel suspend modes: %s\n' "$(</sys/power/mem_sleep)"
        fi

        if [ -r /proc/acpi/wakeup ]; then
          printf '\nRelevant ACPI wake entries:\n'
          grep -Ei '(^|[[:space:]])(XHC|XHCI|USB)[0-9A-Z]*([[:space:]]|$)' /proc/acpi/wakeup || printf '  none matched XHC/XHCI/USB\n'
        fi
      }

      case "''${1:-status}" in
        enable)
          for_each_bridge enable
          ;;
        status)
          show_status
          ;;
        *)
          printf 'Usage: %s {enable|status}\n' "$0" >&2
          exit 2
          ;;
      esac
    '';
  };

  statusTool = pkgs.writeShellApplication {
    name = "ds5-bridge-wakeup-status";
    runtimeInputs = [wakeTool];
    text = ''
      exec ds5-bridge-wakeup status "$@"
    '';
  };

  supportedUsbIds = [
    {
      vendor = "054c";
      product = "0ce6";
    }
    {
      vendor = "054c";
      product = "09cc";
    }
    {
      vendor = "1209";
      product = "db05";
    }
  ];

  wakeRules =
    lib.concatMapStringsSep "\n" (usbId: ''
      ACTION=="add|bind|change", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="${usbId.vendor}", ATTR{idProduct}=="${usbId.product}", RUN+="${wakeTool}/bin/ds5-bridge-wakeup enable"
    '')
    supportedUsbIds;
in {
  options.${id} = {
    enable = lib.mkEnableOption "USB wake support for DS5 Bridge on a Raspberry Pi Pico";

    enableParentWakePath = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable wakeup on the bridge and every wake-capable parent in its USB/PCI path.";
    };

    suspendMode = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["s2idle" "deep"]);
      default = null;
      description = "Optional kernel suspend mode override. Null preserves the firmware/kernel default.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = lib.optional (cfg.suspendMode != null) "mem_sleep_default=${cfg.suspendMode}";

    environment.systemPackages = [
      statusTool
      wakeTool
    ];

    services.udev.extraRules = wakeRules;

    systemd.services = {
      ds5-bridge-wakeup = {
        description = "Enable wakeup through the DS5 Bridge USB path";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${wakeTool}/bin/ds5-bridge-wakeup enable";
        };
      };

      ds5-bridge-wakeup-before-sleep = {
        description = "Reapply DS5 Bridge USB wakeup before sleep";
        wantedBy = ["sleep.target"];
        before = ["sleep.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${wakeTool}/bin/ds5-bridge-wakeup enable";
        };
      };
    };
  };
}
