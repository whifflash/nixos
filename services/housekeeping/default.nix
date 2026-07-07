{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.housekeeping;
  stateDirectory = "/var/lib/infra-housekeeping";

  nixHousekeeping = pkgs.writeShellApplication {
    name = "infra-nix-housekeeping";
    runtimeInputs = with pkgs; [
      coreutils
      nix
    ];
    text = ''
      set -euo pipefail

      state_directory=${lib.escapeShellArg stateDirectory}
      state_file="$state_directory/nix.env"
      temporary_file="$state_file.tmp"
      started_at="$(${pkgs.coreutils}/bin/date +%s)"
      size_before="$(${pkgs.coreutils}/bin/du -sb /nix/store | ${pkgs.coreutils}/bin/cut -f1)"
      result=failed

      finish() {
        local exit_status=$?
        local finished_at
        local size_after
        local reclaimed_bytes

        finished_at="$(${pkgs.coreutils}/bin/date +%s)"
        size_after="$(${pkgs.coreutils}/bin/du -sb /nix/store | ${pkgs.coreutils}/bin/cut -f1)"
        reclaimed_bytes=$((size_before - size_after))
        if [ "$reclaimed_bytes" -lt 0 ]; then
          reclaimed_bytes=0
        fi

        if [ "$exit_status" -eq 0 ]; then
          result=success
        fi

        {
          printf 'result=%s\n' "$result"
          printf 'started_at=%s\n' "$started_at"
          printf 'finished_at=%s\n' "$finished_at"
          printf 'duration_seconds=%s\n' "$((finished_at - started_at))"
          printf 'reclaimed_bytes=%s\n' "$reclaimed_bytes"
        } >"$temporary_file"

        chmod 0644 "$temporary_file"
        mv "$temporary_file" "$state_file"
        trap - EXIT
        exit "$exit_status"
      }

      trap finish EXIT

      nix-collect-garbage --delete-older-than ${lib.escapeShellArg cfg.nix.retentionAge}
      nix-store --optimise
    '';
  };

  podmanHousekeeping = pkgs.writeShellApplication {
    name = "infra-podman-housekeeping";
    runtimeInputs = with pkgs; [
      coreutils
      podman
    ];
    text = ''
      set -euo pipefail

      state_directory=${lib.escapeShellArg stateDirectory}
      state_file="$state_directory/podman.env"
      temporary_file="$state_file.tmp"
      storage_directory=/var/lib/containers/storage
      started_at="$(${pkgs.coreutils}/bin/date +%s)"
      size_before=0
      result=failed

      if [ -d "$storage_directory" ]; then
        size_before="$(${pkgs.coreutils}/bin/du -sb "$storage_directory" | ${pkgs.coreutils}/bin/cut -f1)"
      fi

      finish() {
        local exit_status=$?
        local finished_at
        local size_after=0
        local reclaimed_bytes

        finished_at="$(${pkgs.coreutils}/bin/date +%s)"
        if [ -d "$storage_directory" ]; then
          size_after="$(${pkgs.coreutils}/bin/du -sb "$storage_directory" | ${pkgs.coreutils}/bin/cut -f1)"
        fi

        reclaimed_bytes=$((size_before - size_after))
        if [ "$reclaimed_bytes" -lt 0 ]; then
          reclaimed_bytes=0
        fi

        if [ "$exit_status" -eq 0 ]; then
          result=success
        fi

        {
          printf 'result=%s\n' "$result"
          printf 'started_at=%s\n' "$started_at"
          printf 'finished_at=%s\n' "$finished_at"
          printf 'duration_seconds=%s\n' "$((finished_at - started_at))"
          printf 'reclaimed_bytes=%s\n' "$reclaimed_bytes"
        } >"$temporary_file"

        chmod 0644 "$temporary_file"
        mv "$temporary_file" "$state_file"
        trap - EXIT
        exit "$exit_status"
      }

      trap finish EXIT

      podman image prune --all --force
    '';
  };
in {
  options.infra.services.housekeeping = {
    enable = lib.mkEnableOption "scheduled housekeeping for infrastructure hosts";

    nix = {
      enable =
        lib.mkEnableOption "Nix generation and store housekeeping"
        // {
          default = true;
        };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "Sun *-*-* 05:30:00";
        description = "systemd OnCalendar expression for Nix housekeeping.";
      };

      retentionAge = lib.mkOption {
        type = lib.types.str;
        default = "30d";
        example = "14d";
        description = "Age passed to nix-collect-garbage --delete-older-than.";
      };

      configurationLimit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 5;
        description = "Maximum number of NixOS generations shown by systemd-boot.";
      };
    };

    podman = {
      enable =
        lib.mkEnableOption "Podman image housekeeping"
        // {
          default = true;
        };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "Sun *-*-* 06:15:00";
        description = "systemd OnCalendar expression for Podman image housekeeping.";
      };
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "30min";
      description = "Maximum randomized delay applied to housekeeping timers.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.nix.enable {
      boot.loader.systemd-boot.configurationLimit = cfg.nix.configurationLimit;

      systemd.services.infra-nix-housekeeping = {
        description = "Remove old Nix generations and optimise the Nix store";

        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe nixHousekeeping;
          Nice = 10;
          IOSchedulingClass = "idle";
          StateDirectory = "infra-housekeeping";
        };
      };

      systemd.timers.infra-nix-housekeeping = {
        description = "Scheduled Nix generation and store housekeeping";
        wantedBy = ["timers.target"];

        timerConfig = {
          OnCalendar = cfg.nix.schedule;
          RandomizedDelaySec = cfg.randomizedDelaySec;
          Persistent = true;
        };
      };
    })

    (lib.mkIf cfg.podman.enable {
      systemd.services.infra-podman-housekeeping = {
        description = "Remove Podman images unused by any container";

        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe podmanHousekeeping;
          Nice = 10;
          IOSchedulingClass = "idle";
          StateDirectory = "infra-housekeeping";
        };
      };

      systemd.timers.infra-podman-housekeeping = {
        description = "Scheduled Podman image housekeeping";
        wantedBy = ["timers.target"];

        timerConfig = {
          OnCalendar = cfg.podman.schedule;
          RandomizedDelaySec = cfg.randomizedDelaySec;
          Persistent = true;
        };
      };
    })
  ]);
}
