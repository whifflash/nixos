# hosts/mia-nixbox/default.nix
# NixOS host configuration for "mia", adapted for flake-based imports.
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./../../modules/modules.nix
    inputs.home-manager.nixosModules.default
  ];

  # Bootloader.

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  hardware.graphics.enable = true;

  services = {
    # Enable the X11 windowing system.
    xserver.enable = true;

    # Configure keymap in X11
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Enable CUPS to print documents.
    printing.enable = true;
  };

  networking.hostName = "mianixbox"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  desktop_gnome.enable = false;
  desktop_lightdm.enable = true;
  desktop_budgie.enable = true;
  desktop_sway.enable = false;
  desktop_audio.enable = true;
  base_packages.enable = true;
  base_options.enable = true;
  user_options.enable = true;

  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mhr = {
    isNormalUser = true;
    description = "mhr";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
      #  thunderbird
    ];
  };

  system.stateVersion = "24.11"; # Did you read the comment?
}
