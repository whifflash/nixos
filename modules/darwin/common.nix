{
  config,
  pkgs,
  lib,
  ...
}: {
  system.stateVersion = 6;

  # REQUIRED since activation runs as root; these defaults apply to this user
  system.primaryUser = "mhr";

  nix = {
    # package = pkgs.nixVersions.stable;

    settings = {
      experimental-features = ["nix-command" "flakes"];
      warn-dirty = false;
    };
  };
  # Target Apple Silicon
  nixpkgs.hostPlatform = "aarch64-darwin";

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

  system.defaults = {
    dock.autohide = true;
    dock.tilesize = 48; # host can override
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
  system.activationScripts.installRosetta.text = ''
    if /usr/bin/pgrep oahd >/dev/null 2>&1; then
      echo "Rosetta already installed."
    else
      echo "Installing Rosetta 2…"
      /usr/sbin/softwareupdate --install-rosetta --agree-to-license
    fi
  '';

  # Optional: apply defaults immediately without logout
  # system.activationScripts.postUserActivation.text = ''
  #   /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  # '';
}
