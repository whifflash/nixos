{pkgs, ...}: {
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../services
    ../../modules/core/remote-admin-ssh.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "icarus";
    networkmanager.enable = true;
  };

  nix.settings.experimental-features = [
    "flakes"
    "nix-command"
  ];

  time.timeZone = "Europe/Berlin";

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  users = {
    mutableUsers = false;

    users.mhr = {
      isNormalUser = true;
      description = "mhr";
      extraGroups = ["wheel"];
    };
  };

  security.sudo.wheelNeedsPassword = false;

  remote_admin_ssh = {
    enable = true;
    allowLanAccess = true;
  };

  # nixos-anywhere --copy-host-keys preserves this key across installation.
  # The corresponding public key must be a recipient for infrastructure.yaml.
  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";
    age.generateKey = false;
  };

  infra.services = {
    gitea = {
      enable = true;
      disableRegistration = true;
    };

    housekeeping.enable = true;
    hub.enable = true;
    monitoring = {
      enable = true;
      alerting.testAlerts = {
        enable = true;
        canary.enable = true;
      };
    };
    mosquitto.enable = true;
    ntfy.enable = true;
    paperless.enable = true;
    influxdb.enable = true;
    inverterDataCollector.enable = true;

    homeAssistant = {
      enable = true;
      autoStart = true;
    };

    unifi = {
      enable = true;
      autoStart = true;
    };

    homeAutomationBackup.enable = true;
  };

  zramSwap.enable = true;

  system.stateVersion = "26.05";
}
