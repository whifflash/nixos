# hosts/mia/default.nix
# NixOS host configuration for "mia", adapted for flake-based imports.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  unbind = pkgs.writeShellScript "xhci-unbind-pre" ''
    set -euo pipefail
    DEV=0000:00:14.0
    for D in xhci_hcd xhci_pci; do
      if [ -e "/sys/bus/pci/drivers/$D/unbind" ]; then
        echo "$DEV" > "/sys/bus/pci/drivers/$D/unbind"
        ${pkgs.systemd}/bin/systemd-cat -t xhci-unbind echo "unbound $D:$DEV"
      fi
    done
  '';
  rebind = pkgs.writeShellScript "xhci-unbind-post" ''
    set -euo pipefail
    DEV=0000:00:14.0
    for D in xhci_hcd xhci_pci; do
      if [ -e "/sys/bus/pci/drivers/$D/bind" ]; then
        echo "$DEV" > "/sys/bus/pci/drivers/$D/bind"
        ${pkgs.systemd}/bin/systemd-cat -t xhci-unbind echo "rebound $D:$DEV"
      fi
    done
  '';
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x270
  ];

  # Recommended extras (safe defaults)

  services = {
    fwupd.enable = true; # LVFS firmware updates
    fstrim.enable = true; # SSD TRIM weekly
    power-profiles-daemon.enable = true;
    # services.tlp.enable = true;
    libinput = {
      enable = true;
    };
    logind = {
      # Close lid -> suspend to RAM
      lidSwitch = "suspend";
      lidSwitchExternalPower = "suspend";
      # If docked with external display/keyboard, don't sleep on lid:
      lidSwitchDocked = "suspend"; # set "suspend" if you *do* want it to sleep when docked
    };
    udev.extraRules = ''
      SUBSYSTEM=="usb", ACTION=="add", TEST=="power/wakeup", \
        RUN+="/bin/sh -c 'echo disabled > /sys$devpath/power/wakeup || true'"
    '';
  };

  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault true;
    enableRedistributableFirmware = lib.mkDefault true;

    trackpoint = {
      enable = true;
      speed = 190; # 0–255
      sensitivity = 130; # 0–255
    };
  };

  systemd = {
    services = {
      xhci-unbind = {
        description = "Unbind xHCI (0000:00:14.0) on suspend; rebind on resume";
        wantedBy = ["sleep.target"]; # run for any sleep mode
        before = [
          "systemd-suspend.service"
          "systemd-hibernate.service"
          "systemd-hybrid-sleep.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true; # keeps unit 'active' so ExecStopPost triggers
          ExecStart = "${unbind}";
          ExecStopPost = "${rebind}";
        };
      };

      "irqbalance-x270" = {
        description = "Manually set IRQ affinity for hot devices";
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = pkgs.writeShellScript "irq-affinity" ''
          echo f > /proc/irq/123/smp_affinity  # i915
          echo f > /proc/irq/125/smp_affinity  # xhci
        '';
      };
    };

    sleep.extraConfig = ''
      # Ensure we use RAM sleep
      SuspendState=mem
      # Example: auto-hibernate if left asleep for 1h (requires working hibernate)
      # HibernateDelaySec=1h
    '';
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/mhr/.config/sops/age/keys.txt";
    secrets = {
      "wireguard/vps/keys/public" = {owner = config.users.users."systemd-network".name;};
      "network-manager.env" = {owner = config.users.users."systemd-network".name;};
      # "git/userName" = {};
      # "git/userEmail" = {};
    };
  };

  # Bootloader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [
      "psmouse.synaptics_intertouch=1" # try 0 first; if no joy, try =1
      "i915.enable_dc=0"
      "i915.enable_psr=0"
      "mem_sleep_default=deep"
    ];
  };

  networking.hostName = "mia"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # vpl-gpu-rt # or intel-media-sdk for QSV
    ];
  };

  # Ensure the user exists at the system level
  users.users.mhr = {
    isNormalUser = true;
    # …other user options…
  };

  # Home Manager user binding for this host:
  home-manager.users.mhr = import ../../home/home.nix;
  # or imports = [ ../../home/ssh.nix ../../home/shell.nix ];

  # Greeter
  desktop_sddm.enable = true;
  desktop_greetd.enable = false;

  #Desktop Environments
  programs.sway.enable = true;
  desktop_budgie.enable = false;
  desktop_gdm.enable = false;
  desktop_gnome.enable = false;
  desktop_hyprland.enable = false;

  #Audio
  desktop_audio.enable = true;

  base_packages.enable = true;
  base_options.enable = true;
  user_options.enable = true;

  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = false;
  role_tailscale-node.enable = true;
  role_laptop.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  system.stateVersion = "24.11";

  # Attic cache client (reads endpoint/key/token from secrets)
  attic_client = {
    enable = true;
    secretsFile = ../../secrets/attic.yaml; # encrypted YAML
    addOfficialCache = true;
    fallback = true;
  };

  attic_remote = {
    enable = true;
    hostName = "attic.c4rb0n.cloud"; # or "10.20.31.41"
    sshUser = "mhr";

    system = "x86_64-linux";
    maxJobs = 8;
    speedFactor = 2;
    supportedFeatures = ["kvm" "big-parallel" "nixos-test"];

    sshKey = "/root/.ssh/builder_ed25519";
  };
}
