{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.monitoring;
  certificateName = "wildcard-${config.infra.domain}";
  grafanaSecretKeySecret = "grafana/secret_key";
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "health.${config.infra.domain}";
  textfileDirectory = "/var/lib/prometheus-node-exporter-text-files";

  serviceHostName = service: defaultSubdomain:
    if service.hostName != null
    then service.hostName
    else "${defaultSubdomain}.${config.infra.domain}";

  derivedHttpTargets =
    lib.optionalAttrs config.infra.services.hub.enable {
      hub = "https://${serviceHostName config.infra.services.hub "hub"}";
    }
    // lib.optionalAttrs config.infra.services.gitea.enable {
      gitea = "https://${serviceHostName config.infra.services.gitea "git"}";
    }
    // lib.optionalAttrs config.infra.services.homeAssistant.enable {
      home-assistant = "https://${serviceHostName config.infra.services.homeAssistant "ha"}";
    }
    // lib.optionalAttrs config.infra.services.influxdb.enable {
      influxdb = "https://${serviceHostName config.infra.services.influxdb "influx"}";
    }
    // lib.optionalAttrs config.infra.services.paperless.enable {
      paperless = "https://${serviceHostName config.infra.services.paperless "paperless"}";
    }
    // lib.optionalAttrs config.infra.services.unifi.enable {
      unifi = "https://${serviceHostName config.infra.services.unifi "unifi"}";
    };

  httpTargets = derivedHttpTargets // cfg.additionalHttpTargets;

  derivedTcpTargets =
    lib.optionalAttrs config.infra.services.mosquitto.enable {
      mosquitto = "127.0.0.1:${toString config.infra.services.mosquitto.port}";
    }
    // lib.optionalAttrs config.infra.services.inverterDataCollector.enable {
      inverter-modbus = "${config.infra.services.inverterDataCollector.inverter.host}:${toString config.infra.services.inverterDataCollector.inverter.port}";
    };

  tcpTargets = derivedTcpTargets // cfg.additionalTcpTargets;

  backupUnits =
    lib.optional config.infra.services.gitea.enable "restic-backups-gitea.service"
    ++ lib.optional config.infra.services.homeAutomationBackup.enable "restic-backups-home-automation.service";

  monitoringMetrics = pkgs.writeShellApplication {
    name = "infra-monitoring-metrics";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
    ];
    text = ''
      set -euo pipefail

      output_directory=${lib.escapeShellArg textfileDirectory}
      output_file="$output_directory/infra.prom"
      temporary_file="$output_file.tmp"

      install -d -m 0755 "$output_directory"
      : >"$temporary_file"

      now="$(${pkgs.coreutils}/bin/date +%s)"

      write_backup_metrics() {
        local unit="$1"
        local backup_name="''${unit#restic-backups-}"
        local result
        local timestamp
        local timestamp_seconds=0
        local success=0

        result="$(${pkgs.systemd}/bin/systemctl show "$unit" --property=Result --value 2>/dev/null || true)"
        timestamp="$(${pkgs.systemd}/bin/systemctl show "$unit" --property=InactiveExitTimestamp --value 2>/dev/null || true)"

        if [ "$result" = "success" ]; then
          success=1
        fi

        if [ -n "$timestamp" ] && [ "$timestamp" != "n/a" ]; then
          timestamp_seconds="$(${pkgs.coreutils}/bin/date --date="$timestamp" +%s 2>/dev/null || printf '0')"
        fi

        printf 'infra_backup_last_run_success{backup="%s"} %s\n' "$backup_name" "$success" >>"$temporary_file"
        printf 'infra_backup_last_run_timestamp_seconds{backup="%s"} %s\n' "$backup_name" "$timestamp_seconds" >>"$temporary_file"
      }

      ${lib.concatMapStringsSep "\n" (unit: "write_backup_metrics ${lib.escapeShellArg unit}") backupUnits}

      if [ -e ${lib.escapeShellArg config.infra.services.homeAssistant.zigbeeDevice} ]; then
        zigbee_present=1
      else
        zigbee_present=0
      fi
      printf 'infra_zigbee_coordinator_present %s\n' "$zigbee_present" >>"$temporary_file"

      current_system="$(${pkgs.coreutils}/bin/readlink -f /run/current-system 2>/dev/null || true)"
      profile_system="$(${pkgs.coreutils}/bin/readlink -f /nix/var/nix/profiles/system 2>/dev/null || true)"
      if [ -n "$current_system" ] && [ "$current_system" = "$profile_system" ]; then
        current_profile_active=1
      else
        current_profile_active=0
      fi
      printf 'infra_current_system_profile_active %s\n' "$current_profile_active" >>"$temporary_file"
      printf 'infra_monitoring_metrics_generated_timestamp_seconds %s\n' "$now" >>"$temporary_file"

      chmod 0644 "$temporary_file"
      mv "$temporary_file" "$output_file"
    '';
  };

  prometheusRules = pkgs.writeText "infra-monitoring-rules.yml" (builtins.toJSON {
    groups = [
      {
        name = "icarus-host";
        rules = [
          {
            alert = "FilesystemSpaceLow";
            expr = ''
              (
                node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay"}
                /
                node_filesystem_size_bytes{fstype!~"tmpfs|ramfs|overlay"}
              ) < 0.10
            '';
            for = "15m";
            labels.severity = "warning";
            annotations.summary = "Filesystem space is below 10% on {{ $labels.mountpoint }}";
          }
          {
            alert = "FilesystemInodesLow";
            expr = ''
              (
                node_filesystem_files_free{fstype!~"tmpfs|ramfs|overlay"}
                /
                node_filesystem_files{fstype!~"tmpfs|ramfs|overlay"}
              ) < 0.10
            '';
            for = "15m";
            labels.severity = "warning";
            annotations.summary = "Filesystem inodes are below 10% on {{ $labels.mountpoint }}";
          }
          {
            alert = "MemoryPressure";
            expr = "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10";
            for = "15m";
            labels.severity = "warning";
            annotations.summary = "Available memory has remained below 10%";
          }
          {
            alert = "HostTemperatureHigh";
            expr = "max(node_hwmon_temp_celsius) > 85";
            for = "10m";
            labels.severity = "warning";
            annotations.summary = "A hardware temperature sensor has remained above 85 °C";
          }
          {
            alert = "SystemdUnitFailed";
            expr = ''node_systemd_unit_state{state="failed"} == 1'';
            for = "5m";
            labels.severity = "warning";
            annotations.summary = "systemd unit {{ $labels.name }} is failed";
          }
          {
            alert = "ZigbeeCoordinatorMissing";
            expr = "infra_zigbee_coordinator_present == 0";
            for = "5m";
            labels.severity = "critical";
            annotations.summary = "The configured Zigbee coordinator device is missing";
          }
          {
            alert = "SystemProfileNotActive";
            expr = "infra_current_system_profile_active == 0";
            for = "15m";
            labels.severity = "info";
            annotations.summary = "The active NixOS system differs from the current system profile";
          }
        ];
      }
      {
        name = "icarus-services";
        rules = [
          {
            alert = "ServiceProbeFailed";
            expr = "probe_success == 0";
            for = "5m";
            labels.severity = "critical";
            annotations.summary = "Health probe failed for {{ $labels.instance }}";
          }
          {
            alert = "BackupFailed";
            expr = "infra_backup_last_run_success == 0";
            for = "15m";
            labels.severity = "critical";
            annotations.summary = "The last {{ $labels.backup }} backup did not succeed";
          }
          {
            alert = "BackupStale";
            expr = "time() - infra_backup_last_run_timestamp_seconds > 129600";
            for = "15m";
            labels.severity = "critical";
            annotations.summary = "No completed {{ $labels.backup }} backup has been recorded for 36 hours";
          }
          {
            alert = "MonitoringMetricsStale";
            expr = "time() - infra_monitoring_metrics_generated_timestamp_seconds > 900";
            for = "5m";
            labels.severity = "warning";
            annotations.summary = "Repository-specific monitoring metrics have stopped updating";
          }
        ];
      }
    ];
  });

  blackboxConfig = pkgs.writeText "blackbox-exporter.yml" (builtins.toJSON {
    modules = {
      http_2xx = {
        prober = "http";
        timeout = "10s";
        http = {
          preferred_ip_protocol = "ip4";
          follow_redirects = true;
        };
      };
      tcp_connect = {
        prober = "tcp";
        timeout = "5s";
      };
    };
  });
in {
  options.infra.services.monitoring = {
    enable = lib.mkEnableOption "Prometheus and Grafana infrastructure monitoring";

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "health.example.com";
      description = "DNS name for Grafana. Defaults to health.<infra.domain>.";
    };

    grafanaPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Loopback port used by Grafana and Nginx.";
    };

    prometheusPort = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Loopback port used by Prometheus.";
    };

    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = "30d";
      description = "Prometheus metric retention period.";
    };

    additionalHttpTargets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example.router = "https://192.0.2.1";
      description = "Additional HTTP or HTTPS endpoints probed by the Blackbox exporter.";
    };

    additionalTcpTargets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example.ssh = "192.0.2.10:22";
      description = "Additional TCP endpoints probed by the Blackbox exporter.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.infra.services.hub.enable;
        message = "infra.services.monitoring requires infra.services.hub.enable for the shared wildcard certificate and service link.";
      }
    ];

    infra.acme.enable = true;

    security.acme.certs.${certificateName} = {
      domain = config.infra.domain;
      extraDomainNames = ["*.${config.infra.domain}"];
      group = "nginx";
    };

    sops.secrets.${grafanaSecretKeySecret} = {
      sopsFile = ../../secrets/infrastructure.yaml;
      owner = config.services.grafana.user;
      group = "grafana";
      mode = "0400";
    };

    systemd = {
      services.infra-monitoring-metrics = {
        description = "Generate repository-specific Prometheus metrics";
        after = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${monitoringMetrics}/bin/infra-monitoring-metrics";
        };
      };

      timers.infra-monitoring-metrics = {
        description = "Refresh repository-specific Prometheus metrics";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "2m";
          OnUnitActiveSec = "5m";
          Unit = "infra-monitoring-metrics.service";
        };
      };

      tmpfiles.rules = [
        "d ${textfileDirectory} 0755 root root - -"
      ];
    };

    services = {
      nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts.${hostName} = {
          useACMEHost = certificateName;
          forceSSL = true;
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.grafanaPort}";
            proxyWebsockets = true;
          };
        };
      };

      grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "127.0.0.1";
            http_port = cfg.grafanaPort;
            domain = hostName;
            root_url = "https://${hostName}";
          };

          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
          };

          security = {
            cookie_secure = true;
            secret_key = "$__file{${config.sops.secrets.${grafanaSecretKeySecret}.path}}";
          };

          users = {
            allow_sign_up = false;
            allow_org_create = false;
          };

          "auth.anonymous" = {
            enabled = true;
            org_role = "Viewer";
          };
        };

        provision = {
          enable = true;

          datasources.settings = {
            apiVersion = 1;
            datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString cfg.prometheusPort}";
                isDefault = true;
              }
            ];
          };

          dashboards.settings = {
            apiVersion = 1;
            providers = [
              {
                name = "Infrastructure";
                type = "file";
                options.path = ./dashboards;
              }
            ];
          };
        };
      };

      prometheus = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = cfg.prometheusPort;
        inherit (cfg) retentionTime;
        ruleFiles = [prometheusRules];

        exporters = {
          node = {
            enable = true;
            enabledCollectors = [
              "hwmon"
              "systemd"
              "textfile"
            ];
            extraFlags = [
              "--collector.textfile.directory=${textfileDirectory}"
              "--collector.systemd.unit-include=(gitea|influxdb2|mosquitto|nginx|paperless.*|podman-home-assistant|podman-unifi|inverter-data-collector|restic-backups-.*)\\.service"
            ];
          };

          blackbox = {
            enable = true;
            configFile = blackboxConfig;
          };
        };

        scrapeConfigs = [
          {
            job_name = "node";
            static_configs = [
              {
                targets = ["127.0.0.1:${toString config.services.prometheus.exporters.node.port}"];
                labels.host = config.networking.hostName;
              }
            ];
          }
          {
            job_name = "http-probes";
            metrics_path = "/probe";
            params.module = ["http_2xx"];
            static_configs =
              lib.mapAttrsToList (name: target: {
                targets = [target];
                labels.service = name;
              })
              httpTargets;
            relabel_configs = [
              {
                source_labels = ["__address__"];
                target_label = "__param_target";
              }
              {
                source_labels = ["__param_target"];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
              }
            ];
          }
          {
            job_name = "tcp-probes";
            metrics_path = "/probe";
            params.module = ["tcp_connect"];
            static_configs =
              lib.mapAttrsToList (name: target: {
                targets = [target];
                labels.service = name;
              })
              tcpTargets;
            relabel_configs = [
              {
                source_labels = ["__address__"];
                target_label = "__param_target";
              }
              {
                source_labels = ["__param_target"];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
              }
            ];
          }
        ];
      };
    };
  };
}
