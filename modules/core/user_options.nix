{ pkgs, config, lib, ... }:
let 
id = "user_options";
cfg = config.${id};
in 
{
options.${id} = {
enable = lib.mkEnableOption "enables ${id} profile";
};

config = lib.mkIf cfg.enable {

  programs.zsh.enable = true;
  programs.zsh.ohMyZsh = {
    enable = true;
    plugins = ["git"];
    theme = "agnoster";
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.mhr = {
    isNormalUser = true;
    description = "mhr";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    #  thunderbird
    ];
    shell = pkgs.zsh;
  };

};



}
