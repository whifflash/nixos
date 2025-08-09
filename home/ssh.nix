{ config, pkgs, ... }:
{
    programs.ssh = {
        enable = true;
        controlPersist = "12h";
        controlMaster = "auto";

        matchBlocks = {
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
          "ikarus" = {
              user = "mhr";
              hostname = "10.20.31.41";
              identityFile = "/home/mhr/.ssh/gitea";
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