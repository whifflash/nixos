{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.infra.services.monitoring;
  certificateName = "wildcard-${config.infra.domain}";
  grafanaSecretKeySecret = "grafana/secret_key";
  mqttPasswordSecret = "monitoring/mqtt_password";
  mqttPasswordHashSecret = "mosquitto/users/monitoring/password_hash";
  ntfyPasswordSecret = "ntfy/users/alertmanager/password";
  hostName =
    if cfg.hostName != null
    then cfg.hostName
    else "health.${config.infra.domain}";
  textfileDirectory = "/var/lib/prometheus-node-exporter-text-files";

  monitoringPython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.paho-mqtt
  ]);

  monitoringTestAlert = pkgs.writeShellApplication {
    name = "infra-monitoring-test-alert";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];
    text = builtins.readFile ./scripts/monitoring-test-alert.sh;
  };

  monitoringAlertCanary = pkgs.writeShellApplication {
    name = "infra-monitoring-alert-canary";
    runtimeInputs = [
      monitoringTestAlert
      pkgs.coreutils
    ];
    text = builtins.readFile ./scripts/monitoring-alert-canary.sh;
  };

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
    // lib.optionalAttrs config.infra.services.ntfy.enable {
      ntfy = "https://${serviceHostName config.infra.services.ntfy "ntfy"}";
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
      jq
      nix
      podman
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

      nix_store_json="$(${pkgs.nix}/bin/nix path-info --all --json)"
      nix_store_size_bytes="$(printf '%s' "$nix_store_json" | ${pkgs.jq}/bin/jq 'if type == "array" then map(.narSize // 0) | add // 0 else [.[] | .narSize // 0] | add // 0 end')"
      nix_store_path_count="$(printf '%s' "$nix_store_json" | ${pkgs.jq}/bin/jq 'length')"
      generation_count=0
      oldest_generation_timestamp=0

      for generation in /nix/var/nix/profiles/system-*-link; do
        if [ ! -e "$generation" ]; then
          continue
        fi

        generation_count=$((generation_count + 1))
        generation_timestamp="$(${pkgs.coreutils}/bin/stat --format=%Y "$generation")"
        if [ "$oldest_generation_timestamp" -eq 0 ] || [ "$generation_timestamp" -lt "$oldest_generation_timestamp" ]; then
          oldest_generation_timestamp="$generation_timestamp"
        fi
      done

      {
        printf 'infra_nix_store_size_bytes %s\n' "$nix_store_size_bytes"
        printf 'infra_nix_store_path_count %s\n' "$nix_store_path_count"
        printf 'infra_nixos_system_generation_count %s\n' "$generation_count"
        printf 'infra_nixos_oldest_generation_timestamp_seconds %s\n' "$oldest_generation_timestamp"
      } >>"$temporary_file"

      podman_image_count=0
      podman_image_size_bytes=0
      podman_reclaimable_image_count=0
      podman_reclaimable_image_size_bytes=0
      declare -A podman_used_images=()

      mapfile -t podman_container_ids < <(${pkgs.podman}/bin/podman container ls --all --quiet 2>/dev/null || true)
      if [ "''${#podman_container_ids[@]}" -gt 0 ]; then
        while IFS= read -r image_id; do
          if [ -n "$image_id" ]; then
            podman_used_images["$image_id"]=1
          fi
        done < <(${pkgs.podman}/bin/podman container inspect --format '{{.Image}}' "''${podman_container_ids[@]}" 2>/dev/null || true)
      fi

      while IFS=' ' read -r image_id image_size; do
        if [ -z "$image_id" ] || [ -z "$image_size" ]; then
          continue
        fi

        podman_image_count=$((podman_image_count + 1))
        podman_image_size_bytes=$((podman_image_size_bytes + image_size))

        if [ -z "''${podman_used_images[$image_id]+present}" ]; then
          podman_reclaimable_image_count=$((podman_reclaimable_image_count + 1))
          podman_reclaimable_image_size_bytes=$((podman_reclaimable_image_size_bytes + image_size))
        fi
      done < <(
        while IFS= read -r image_id; do
          if [ -n "$image_id" ]; then
            ${pkgs.podman}/bin/podman image inspect --format '{{.Id}} {{.Size}}' "$image_id" 2>/dev/null || true
          fi
        done < <(${pkgs.podman}/bin/podman image ls --quiet --no-trunc 2>/dev/null | ${pkgs.coreutils}/bin/sort --unique)
      )

      {
        printf 'infra_podman_image_count %s\n' "$podman_image_count"
        printf 'infra_podman_image_size_bytes %s\n' "$podman_image_size_bytes"
        printf 'infra_podman_reclaimable_image_count %s\n' "$podman_reclaimable_image_count"
        printf 'infra_podman_reclaimable_image_size_bytes %s\n' "$podman_reclaimable_image_size_bytes"
      } >>"$temporary_file"

      write_housekeeping_metrics() {
        local task_name="$1"
        local state_file="/var/lib/infra-housekeeping/$task_name.env"
        local result=unknown
        local finished_at=0
        local duration_seconds=0
        local reclaimed_bytes=0
        local success=0

        if [ -r "$state_file" ]; then
          while IFS='=' read -r key value; do
            case "$key" in
              result)
                result="$value"
                ;;
              finished_at)
                finished_at="$value"
                ;;
              duration_seconds)
                duration_seconds="$value"
                ;;
              reclaimed_bytes)
                reclaimed_bytes="$value"
                ;;
            esac
          done <"$state_file"
        fi

        if [ "$result" = "success" ]; then
          success=1
        fi

        {
          printf 'infra_housekeeping_last_run_success{task="%s"} %s\n' "$task_name" "$success"
          printf 'infra_housekeeping_last_run_timestamp_seconds{task="%s"} %s\n' "$task_name" "$finished_at"
          printf 'infra_housekeeping_last_run_duration_seconds{task="%s"} %s\n' "$task_name" "$duration_seconds"
          printf 'infra_housekeeping_last_reclaimed_bytes{task="%s"} %s\n' "$task_name" "$reclaimed_bytes"
        } >>"$temporary_file"
      }

      ${lib.optionalString (config.infra.services.housekeeping.enable && config.infra.services.housekeeping.nix.enable) "write_housekeeping_metrics nix"}
      ${lib.optionalString (config.infra.services.housekeeping.enable && config.infra.services.housekeeping.podman.enable) "write_housekeeping_metrics podman"}

      printf 'infra_monitoring_metrics_generated_timestamp_seconds %s\n' "$now" >>"$temporary_file"

      chmod 0644 "$temporary_file"
      mv "$temporary_file" "$output_file"
    '';
  };

  prometheusRules = pkgs.writeText "infra-monitoring-rules.yml" (builtins.toJSON {
    groups =
      [
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
              alert = "HousekeepingFailed";
              expr = "infra_housekeeping_last_run_timestamp_seconds > 0 and infra_housekeeping_last_run_success == 0";
              for = "15m";
              labels.severity = "warning";
              annotations.summary = "The last {{ $labels.task }} housekeeping run failed";
            }
            {
              alert = "HousekeepingStale";
              expr = "infra_housekeeping_last_run_timestamp_seconds > 0 and time() - infra_housekeeping_last_run_timestamp_seconds > 691200";
              for = "30m";
              labels.severity = "warning";
              annotations.summary = "No completed {{ $labels.task }} housekeeping run has been recorded for eight days";
            }
            {
              alert = "MqttRoundtripFailed";
              expr = "infra_mqtt_roundtrip_success == 0";
              for = "5m";
              labels.severity = "critical";
              annotations.summary = "Authenticated MQTT publish/subscribe round trip is failing";
            }
            {
              alert = "MqttTopicStale";
              expr = "infra_mqtt_topic_last_message_timestamp_seconds > 0 and time() - infra_mqtt_topic_last_message_timestamp_seconds > 300";
              for = "5m";
              labels.severity = "warning";
              annotations.summary = "MQTT topic {{ $labels.name }} has not produced a message for five minutes";
            }
            {
              alert = "MqttTopicUnhealthy";
              expr = "infra_mqtt_topic_healthy == 0";
              for = "5m";
              labels.severity = "critical";
              annotations.summary = "MQTT topic {{ $labels.name }} is missing or reports an unhealthy payload";
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
      ]
      ++ lib.optionals cfg.alerting.testAlerts.enable [
        {
          name = "icarus-alert-delivery-tests";
          rules = [
            {
              alert = "MonitoringTestAlert";
              expr = ''infra_monitoring_test_alert{test_id!="scheduled-canary"} == 1'';
              for = "30s";
              labels = {
                category = "notification";
                service = "monitoring-test";
                severity = "{{ $labels.severity }}";
              };
              annotations = {
                description = "Controlled end-to-end alert-delivery test {{ $labels.test_id }} is active.";
                summary = "Monitoring test ({{ $labels.severity }}): {{ $labels.test_id }}";
              };
            }
            {
              alert = "MonitoringDeliveryCanary";
              expr = ''infra_monitoring_test_alert{test_id="scheduled-canary"} == 1'';
              for = "30s";
              labels = {
                category = "notification-canary";
                service = "monitoring-test";
                severity = "{{ $labels.severity }}";
                ntfy_topic = cfg.alerting.testAlerts.canary.topic;
              };
              annotations = {
                description = "Scheduled end-to-end notification delivery canary.";
                summary = "Scheduled notification test reached Alertmanager";
              };
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
      default = 3001;
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

    alerting = {
      enable = lib.mkEnableOption "Alertmanager notifications through ntfy" // {default = true;};

      ntfyUsername = lib.mkOption {
        type = lib.types.str;
        default = "alertmanager";
        description = "ntfy user used by the Alertmanager adapter.";
      };

      ntfyPasswordSecret = lib.mkOption {
        type = lib.types.str;
        default = ntfyPasswordSecret;
        description = "SOPS key containing the ntfy publisher password.";
      };

      webhookPort = lib.mkOption {
        type = lib.types.port;
        default = 9095;
        description = "Loopback port for the Alertmanager-to-ntfy adapter.";
      };

      testAlerts = {
        enable = lib.mkEnableOption "controlled end-to-end alert-delivery tests";

        canary = {
          enable = lib.mkEnableOption "scheduled end-to-end notification canaries";

          schedule = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "Wed *-*-* 10:00:00"
              "Sun *-*-* 19:10:00"
            ];
            description = "systemd OnCalendar expressions for notification canaries.";
          };

          severity = lib.mkOption {
            type = lib.types.enum [
              "critical"
              "warning"
              "info"
            ];
            default = "critical";
            description = "Severity attached to scheduled notification canaries.";
          };

          topic = lib.mkOption {
            type = lib.types.str;
            default = config.infra.services.ntfy.topics.critical;
            description = "ntfy topic used for scheduled notification canaries.";
          };

          activeDuration = lib.mkOption {
            type = lib.types.str;
            default = "2m";
            description = "How long the synthetic metric remains active before automatic cleanup.";
          };
        };
      };
    };

    mqtt = {
      enable = lib.mkEnableOption "authenticated MQTT health and topic freshness checks" // {default = true;};

      username = lib.mkOption {
        type = lib.types.str;
        default = "monitoring";
        description = "Dedicated Mosquitto username used by the monitoring probe.";
      };

      passwordSecret = lib.mkOption {
        type = lib.types.str;
        default = mqttPasswordSecret;
        description = "SOPS key containing the MQTT monitoring user's plaintext password.";
      };

      passwordHashSecret = lib.mkOption {
        type = lib.types.str;
        default = mqttPasswordHashSecret;
        description = "SOPS key containing the Mosquitto password hash for the monitoring user.";
      };

      roundtripTopic = lib.mkOption {
        type = lib.types.str;
        default = "infra/monitoring/roundtrip";
        description = "MQTT topic used for the publish/subscribe round-trip probe.";
      };

      topics = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {type = lib.types.str;};
            topic = lib.mkOption {type = lib.types.str;};
            expectedPayload = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          };
        });
        default = lib.optionals config.infra.services.inverterDataCollector.enable [
          {
            name = "inverter-availability";
            topic = config.infra.services.inverterDataCollector.mqtt.availabilityTopic;
            expectedPayload = "online";
          }
          {
            name = "inverter-state";
            topic = config.infra.services.inverterDataCollector.mqtt.stateTopic;
          }
        ];
        description = "Important MQTT topics whose presence, freshness, and optional payload are monitored.";
      };
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
        assertion = !cfg.mqtt.enable || config.infra.services.mosquitto.enable;
        message = "infra.services.monitoring.mqtt requires infra.services.mosquitto.enable.";
      }
      {
        assertion = !cfg.alerting.enable || config.infra.services.ntfy.enable;
        message = "infra.services.monitoring.alerting requires infra.services.ntfy.enable.";
      }
      {
        assertion = !cfg.alerting.testAlerts.canary.enable || cfg.alerting.testAlerts.enable;
        message = "infra.services.monitoring.alerting.testAlerts.canary requires testAlerts.enable.";
      }
      {
        assertion = !cfg.alerting.testAlerts.canary.enable || builtins.elem cfg.alerting.testAlerts.canary.topic (builtins.attrValues config.infra.services.ntfy.topics);
        message = "The alert canary topic must be one of infra.services.ntfy.topics.";
      }
      {
        assertion = config.infra.services.hub.enable;
        message = "infra.services.monitoring requires infra.services.hub.enable for the shared wildcard certificate and service link.";
      }
    ];

    infra.acme.enable = true;

    environment.systemPackages = lib.optionals cfg.alerting.testAlerts.enable [
      monitoringTestAlert
    ];

    security.acme.certs.${certificateName} = {
      domain = config.infra.domain;
      extraDomainNames = ["*.${config.infra.domain}"];
      group = "nginx";
    };

    sops.secrets = lib.mkMerge [
      {
        ${grafanaSecretKeySecret} = {
          sopsFile = ../../secrets/infrastructure.yaml;
          owner = config.users.users.grafana.name;
          group = config.users.users.grafana.group;
          mode = "0400";
        };
      }

      (lib.mkIf cfg.mqtt.enable {
        ${cfg.mqtt.passwordSecret} = {
          sopsFile = ../../secrets/infrastructure.yaml;
          key = cfg.mqtt.passwordSecret;
          mode = "0400";
        };
      })

      (lib.mkIf cfg.alerting.enable {
        ${cfg.alerting.ntfyPasswordSecret} = {
          sopsFile = ../../secrets/infrastructure.yaml;
          key = cfg.alerting.ntfyPasswordSecret;
          mode = "0400";
        };
      })
    ];

    infra.services.mosquitto.additionalUsers = lib.mkIf cfg.mqtt.enable {
      ${cfg.mqtt.username} = {
        passwordSecret = cfg.mqtt.passwordHashSecret;
        acl =
          [
            "readwrite ${cfg.mqtt.roundtripTopic}"
          ]
          ++ map (topic: "read ${topic.topic}") cfg.mqtt.topics;
      };
    };

    systemd = {
      services = {
        infra-monitoring-metrics = {
          description = "Generate repository-specific Prometheus metrics";
          after = ["multi-user.target"];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${monitoringMetrics}/bin/infra-monitoring-metrics";
          };
        };

        infra-monitoring-mqtt = lib.mkIf cfg.mqtt.enable {
          description = "Probe MQTT round-trip and important topic freshness";
          after = ["mosquitto.service"];
          requires = ["mosquitto.service"];
          environment = {
            MQTT_HOST = "127.0.0.1";
            MQTT_PORT = toString config.infra.services.mosquitto.port;
            MQTT_USERNAME = cfg.mqtt.username;
            MQTT_ROUNDTRIP_TOPIC = cfg.mqtt.roundtripTopic;
            MQTT_TOPICS_JSON = builtins.toJSON cfg.mqtt.topics;
            MQTT_TIMEOUT_SECONDS = "15";
            MQTT_METRICS_FILE = "${textfileDirectory}/mqtt.prom";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${monitoringPython}/bin/python ${./scripts/mqtt_probe.py}";
            LoadCredential = "mqtt-password:${config.sops.secrets.${cfg.mqtt.passwordSecret}.path}";
            StateDirectory = "infra-monitoring-mqtt";
          };
        };

        infra-monitoring-alert-canary = lib.mkIf cfg.alerting.testAlerts.canary.enable {
          description = "Send a scheduled end-to-end monitoring notification canary";
          after = [
            "prometheus-node-exporter.service"
            "prometheus.service"
            "prometheus-alertmanager.service"
            "infra-alertmanager-ntfy.service"
            "ntfy-sh.service"
          ];
          wants = [
            "prometheus-node-exporter.service"
            "prometheus.service"
            "prometheus-alertmanager.service"
            "infra-alertmanager-ntfy.service"
            "ntfy-sh.service"
          ];
          environment = {
            ALERT_ACTIVE_DURATION = cfg.alerting.testAlerts.canary.activeDuration;
            ALERT_SEVERITY = cfg.alerting.testAlerts.canary.severity;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${monitoringAlertCanary}/bin/infra-monitoring-alert-canary";
          };
        };

        infra-alertmanager-ntfy = lib.mkIf cfg.alerting.enable {
          description = "Forward Alertmanager notifications to ntfy";
          wantedBy = ["multi-user.target"];
          after = ["ntfy-sh.service"];
          requires = ["ntfy-sh.service"];
          environment = {
            LISTEN_PORT = toString cfg.alerting.webhookPort;
            GRAFANA_URL = "https://${hostName}";
            NTFY_BASE_URL = "https://${serviceHostName config.infra.services.ntfy "ntfy"}";
            NTFY_USERNAME = cfg.alerting.ntfyUsername;
            NTFY_TOPICS_JSON = builtins.toJSON config.infra.services.ntfy.topics;
          };
          serviceConfig = {
            Type = "simple";
            ExecStart = "${pkgs.python3}/bin/python ${./scripts/alertmanager_ntfy.py}";
            LoadCredential = "ntfy-password:${config.sops.secrets.${cfg.alerting.ntfyPasswordSecret}.path}";
            Restart = "on-failure";
            RestartSec = "10s";
            DynamicUser = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
          };
        };
      };

      timers = {
        infra-monitoring-alert-canary = lib.mkIf cfg.alerting.testAlerts.canary.enable {
          description = "Schedule end-to-end monitoring notification canaries";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = cfg.alerting.testAlerts.canary.schedule;
            Persistent = true;
            Unit = "infra-monitoring-alert-canary.service";
          };
        };

        infra-monitoring-metrics = {
          description = "Refresh repository-specific Prometheus metrics";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "2m";
            OnUnitActiveSec = "5m";
            Unit = "infra-monitoring-metrics.service";
          };
        };

        infra-monitoring-mqtt = lib.mkIf cfg.mqtt.enable {
          description = "Refresh MQTT health metrics";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnBootSec = "1m";
            OnUnitActiveSec = "1m";
            Unit = "infra-monitoring-mqtt.service";
          };
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
        alertmanager = lib.mkIf cfg.alerting.enable {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9093;
          configuration = {
            route = {
              receiver = "ntfy";
              group_by = ["alertname" "severity"];
              group_wait = "30s";
              group_interval = "5m";
              repeat_interval = "4h";
              routes = lib.optionals cfg.alerting.testAlerts.canary.enable [
                {
                  receiver = "ntfy-canary";
                  matchers = [''category="notification-canary"''];
                  continue = false;
                }
              ];
            };
            receivers = [
              {
                name = "ntfy";
                webhook_configs = [
                  {
                    url = "http://127.0.0.1:${toString cfg.alerting.webhookPort}";
                    send_resolved = true;
                  }
                ];
              }
              {
                name = "ntfy-canary";
                webhook_configs = [
                  {
                    url = "http://127.0.0.1:${toString cfg.alerting.webhookPort}";
                    send_resolved = false;
                  }
                ];
              }
            ];
          };
        };

        enable = true;
        listenAddress = "127.0.0.1";
        port = cfg.prometheusPort;
        inherit (cfg) retentionTime;
        ruleFiles = [prometheusRules];
        alertmanagers = lib.optionals cfg.alerting.enable [
          {
            static_configs = [
              {
                targets = ["127.0.0.1:9093"];
              }
            ];
          }
        ];

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
