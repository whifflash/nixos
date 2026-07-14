{
  lib,
  pkgs,
  ...
}: {
  system = {
    stateVersion = 6;
    primaryUser = "mhr";
    defaults = {
      dock = {
        autohide = false;
        mru-spaces = false; # don’t auto-rearrange Spaces
        tilesize = 48; # host can override
      };
      spaces = {
        # Required for sane AeroSpace multi-monitor behavior. This disables
        # “Displays have separate Spaces” so one macOS Space spans all displays.
        # macOS requires logging out and back in before this takes full effect.
        spans-displays = true;
      };

      finder = {
        AppleShowAllExtensions = true;
        FXPreferredViewStyle = "Nlsv";
        _FXShowPosixPathInTitle = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
      };
    };

    # Rosetta 2 (installs once, no-op if present)
    activationScripts.installRosetta.text = ''
      if /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "Rosetta already installed."
      else
        echo "Installing Rosetta 2…"
        /usr/sbin/softwareupdate --install-rosetta --agree-to-license
      fi
    '';
  };

  nix = {
    # package = pkgs.nixVersions.stable;

    settings = {
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "mhr"];
      builders-use-substitutes = true;
      # builders = "ssh-ng://YOUR_LINUX_USER@icarus x86_64-linux - 4 1 big-parallel,kvm";
    };

    #settings = {
    #  experimental-features = ["nix-command" "flakes"];
    #  warn-dirty = false;
    #};
  };
  # Target Apple Silicon
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfreePredicate = pkg: lib.getName pkg == "claude-code";

  # Useful tools
  environment.systemPackages = with pkgs; [
    git
    gnupg
    jq
    tree
    curl
    wget
    htop
    ripgrep
    fd
  ];

  # macOS defaults (these will now apply to system.primaryUser)
  programs.zsh.enable = true;

  # Optional: apply defaults immediately without logout
  # system.activationScripts.postUserActivation.text = ''
  #   /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  # '';
}
