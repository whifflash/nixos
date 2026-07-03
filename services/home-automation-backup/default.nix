{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.homeAutomationBackup;
  homeAssistantUnit = "${config.virtualisation.oci-containers.containers."home-assistant".serviceName}.service";
  operatorTokenSecret = "influxdb/operator_token";
  resticPasswordSecret = "restic/home_automation/repository_password";
  resticEnvironmentSecret = "restic/home_automation/environment";
in {
  options.infra.services.homeAutomationBackup = {
    enable = lib.mkEnableOption "the combined Home Assistant, Mosquitto, and InfluxDB backup";

    repository = lib.mkOption {
      type = lib.types.str;
      default = "rest:https://restic.c4rb0n.cloud/restic-home-automation";
      description = "Restic repository used for the home-automation stack.";
    };

    stagingRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/backup/home-automation";
      description = "Local staging directory uploaded by Restic.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "04:30";
      description = "systemd OnCalendar expression for the backup.";
    };

    timeoutStartSec = lib.mkOption {
      type = lib.types.str;
      default = "2h";
      description = "Maximum duration of one backup service invocation.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.infra.services.homeAssistant.enable;
        message = "homeAutomationBackup requires infra.services.homeAssistant.enable";
      }
      {
        assertion = config.infra.services.homeAssistant.autoStart;
        message = "homeAutomationBackup requires Home Assistant autoStart after cutover";
      }
      {
        assertion = config.infra.services.mosquitto.enable;
        message = "homeAutomationBackup requires infra.services.mosquitto.enable";
      }
      {
        assertion = config.infra.services.influxdb.enable;
        message = "homeAutomationBackup requires infra.services.influxdb.enable";
      }
    ];

    sops.secrets = {
      ${resticPasswordSecret} = {
        sopsFile = ../../secrets/infrastructure.yaml;
        key = resticPasswordSecret;
        format = "yaml";
        mode = "0400";
      };

      ${resticEnvironmentSecret} = {
        sopsFile = ../../secrets/infrastructure.yaml;
        key = resticEnvironmentSecret;
        format = "yaml";
        mode = "0400";
      };
    };

    systemd = {
      services."restic-backups-home-automation".serviceConfig.TimeoutStartSec = cfg.timeoutStartSec;

      tmpfiles.rules = [
        "d ${cfg.stagingRoot} 0700 root root - -"
      ];
    };

    services.restic.backups."home-automation" = {
      inherit (cfg) repository;
      passwordFile = config.sops.secrets.${resticPasswordSecret}.path;
      environmentFile = config.sops.secrets.${resticEnvironmentSecret}.path;
      paths = ["${cfg.stagingRoot}/current"];
      initialize = true;

      backupPrepareCommand = ''
        set -euo pipefail

        restart_services() {
          ${pkgs.systemd}/bin/systemctl start mosquitto.service
          ${pkgs.systemd}/bin/systemctl start ${homeAssistantUnit}
        }

        trap restart_services EXIT
        ${pkgs.systemd}/bin/systemctl stop ${homeAssistantUnit}
        ${pkgs.systemd}/bin/systemctl stop mosquitto.service

        ${pkgs.coreutils}/bin/rm -rf ${cfg.stagingRoot}/current
        ${pkgs.coreutils}/bin/install -d -m 0700 \
          ${cfg.stagingRoot}/current/home-assistant \
          ${cfg.stagingRoot}/current/mosquitto

        ${pkgs.rsync}/bin/rsync \
          --archive \
          --hard-links \
          --acls \
          --xattrs \
          --numeric-ids \
          --delete \
          /var/lib/home-assistant/ \
          ${cfg.stagingRoot}/current/home-assistant/

        ${pkgs.rsync}/bin/rsync \
          --archive \
          --hard-links \
          --acls \
          --xattrs \
          --numeric-ids \
          --delete \
          /var/lib/mosquitto/ \
          ${cfg.stagingRoot}/current/mosquitto/

        ${pkgs.influxdb2-cli}/bin/influx backup \
          --host http://127.0.0.1:${toString config.infra.services.influxdb.httpPort} \
          --token "$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.${operatorTokenSecret}.path})" \
          ${cfg.stagingRoot}/current/influxdb

        restart_services
        trap - EXIT
      '';

      backupCleanupCommand = ''
        set -euo pipefail
        ${pkgs.systemd}/bin/systemctl start mosquitto.service
        ${pkgs.systemd}/bin/systemctl start ${homeAssistantUnit}
      '';

      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 3"
        "--group-by host,paths"
      ];
    };
  };
}
