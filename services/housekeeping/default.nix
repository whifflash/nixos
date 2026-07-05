{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.housekeeping;

  nixHousekeeping = pkgs.writeShellApplication {
    name = "infra-nix-housekeeping";
    runtimeInputs = with pkgs; [
      coreutils
      nix
    ];
    text = ''
      set -euo pipefail

      nix-collect-garbage --delete-older-than ${lib.escapeShellArg cfg.nix.retentionAge}
      nix-store --optimise
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
          ExecStart = "${pkgs.podman}/bin/podman image prune --all --force";
          Nice = 10;
          IOSchedulingClass = "idle";
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
