{
  lib,
  config,
  inputs ? {},
  ...
}: let
  haveInputsSops = inputs ? sops-nix;
in {
  imports = lib.optionals haveInputsSops [inputs.sops-nix.homeManagerModules.sops];

  # SOPS secret managed by Home Manager
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets."bsw/priv" = {
      sopsFile = inputs.self + /../secrets/ssh.yaml; # <-- key change
      path = "${config.home.homeDirectory}/.ssh/bsw";
    };
  };

  programs.ssh = {
    enable = true;

    matchBlocks = {
      "*" = {
        controlPersist = "12h";
        controlMaster = "auto";
      };
      "github.com" = {
        user = "git";
        hostname = "github.com";
        identityFile = "/home/mhr/.ssh/githubwhifflash";
        identitiesOnly = true;
        port = 22;
      };

      "wgbsw.vps.webdock.cloud" = {
        user = "mhr";
        hostname = "vps";
        identityFile = "/home/mhr/.ssh/webdockvps";
        identitiesOnly = true;
        port = 22;
      };
      "git.c4rb0n.cloud 10.20.31.41" = {
        user = "git";
        hostname = "git.c4rb0n.cloud";
        identityFile = "/home/mhr/.ssh/gitea";
        identitiesOnly = true;
        port = 2222;
      };
      "icarus 10.20.31.41 attic.c4rb0n.cloud" = {
        user = "mhr";
        hostname = "10.20.31.41";
        identityFile = "~/.ssh/bsw";
        identitiesOnly = true; # ensures the specified key is used
        port = 22;
      };
      "poseidon" = {
        user = "mhr";
        hostname = "127.0.0.1";
        proxyJump = "vps";
        dynamicForwards = [{port = 1080;}];
      };
    };
  };
  services.ssh-agent.enable = false;
}
