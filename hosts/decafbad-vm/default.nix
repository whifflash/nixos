# hosts/mia/decafbad-vm.nix
# NixOS host configuration for "mia", adapted for flake-based imports.
{
  # inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    # inputs.home-manager.nixosModules.default
    # inputs.home-manager.nixosModules.default
    # inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/mhr/.config/sops/age/keys.txt";

    secrets."wireguard/vps/keys/public" = {
      owner = config.users.users."systemd-network".name;
    };
    secrets."network-manager.env" = {
      owner = config.users.users."systemd-network".name;
    };
  }; # end of sops = {};

  # Bootloader options

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  networking.hostName = "nixbox";

  desktop_gnome.enable = true;
  desktop_greetd.enable = true;
  desktop_hyprland.enable = false;
  desktop_sway.enable = false;
  desktop_audio.enable = true;
  base_packages.enable = true;
  base_options.enable = true;
  virtualization_guest.enable = true;
  role_workstation.enable = true;
  role_hardware-development.enable = true;

  networking.networkmanager.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mhr = {
    isNormalUser = true;
    description = "mhr";
    extraGroups = ["networkmanager" "wheel" "vboxsf"];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  # System specific Joplin-Backup script
  # Joplin won't sync to a shared folder

  systemd.timers."joplin-backup" = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "joplin-backup.service";
    };
  };

  systemd.services."joplin-backup" = {
    script = ''
      set -eu
      ${pkgs.coreutils}/bin/cp -r /home/mhr/Joplin-Backup/* /home/mhr/share/Joplin/Backup/
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "mhr";
    };
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
