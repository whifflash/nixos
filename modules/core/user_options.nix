{
  pkgs,
  config,
  lib,
  ...
}: let
  id = "user_options";
  cfg = config.${id};
in {
  options.${id} = {
    enable = lib.mkEnableOption "enables ${id} profile";
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;

      # Keep oh-my-zsh managed by NixOS.
      ohMyZsh = {
        enable = true;
        # Leave theme empty so it doesn't fight our custom prompt.
        theme = "";
        plugins = [
          "git"
          "sudo"
          "fzf"
          "colored-man-pages"
          # add/remove as you like
        ];
      };
    };

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.mhr = {
      isNormalUser = true;
      description = "mhr";
      extraGroups = ["networkmanager" "wheel" "video" "dialout" "plugdev"];
      packages = with pkgs; [
        #  thunderbird
      ];
      shell = pkgs.zsh;
    };

    environment = {
      sessionVariables.ZDOTDIR = "${config.users.users.mhr.home}/.config/zsh";
      systemPackages = with pkgs; [
        fzf
      ];
    };
  };
}
