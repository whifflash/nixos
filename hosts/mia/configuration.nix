# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./../../modules/modules.nix  
      inputs.home-manager.nixosModules.default
      inputs.stylix.nixosModules.stylix
      inputs.sops-nix.nixosModules.sops
    ];
  sops.defaultSopsFile = ../secrets/secrets.yaml;
  sops.defaltSopsFormat = "yaml";

  sops.age.keyFile = "$HOME/.config/age/keys.txt";

  # ${specialArgs.hostname}

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mia"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;

  # Put in laptop role
  programs.light.enable = true;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # vpl-gpu-rt # or intel-media-sdk for QSV
    ];
  };

  desktop_gdm.enable = false;
  desktop_sddm.enable = true;
  desktop_gnome.enable = true;
  desktop_greetd.enable = false;
  desktop_hyprland.enable = true;
  desktop_sway.enable = false;
  desktop_audio.enable = true;
  base_packages.enable = true;
  base_options.enable = true;
  user_options.enable = true;

  virtualization_guest.enable = false;
  role_workstation.enable = true;
  role_hardware-development.enable = true;


    # Enable WireGuard
  networking.wireguard.enable = true;
  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [ "10.100.0.2/24" ];
      # listenPort = 51820; # to match firewall allowedUDPPorts (without this wg uses random port numbers)

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKey = "$(cat ${config.sops.secrets."wireguard.${specialArgs.hostname}.keys.private".path})";

      peers = [
        # For a client configuration, one peer entry for the server will suffice.

        {
          # Public key of the server (not a file path).
          publicKey = "{server public key}";

          # Forward all the traffic via VPN.
          allowedIPs = [ "10.20.0.1/24" ];
          # Or forward only particular subnets
          #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

          # Set this to the server IP and port.
          endpoint = "{server ip}:51823"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  # stylix = {
  #   enable = true;
  #   base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  #   image = ../../media/wallpapers/anna-scarfiello.jpg;
  # };


  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

#   users.users.mhr.isNormalUser = true;
#   home-manager.users.mhr = { pkgs, ... }: {
#   home.packages = [ pkgs.atool pkgs.httpie ];
#   programs.bash.enable = true;

#   # The state version is required and should stay at the version you
#   # originally installed.
#   home.stateVersion = "24.05";
# };

  system.stateVersion = "24.11";

}
