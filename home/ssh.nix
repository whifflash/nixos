{
  lib,
  config,
  inputs ? { },
  ...
}:
let
  haveInputsSops = inputs ? sops-nix;
in
{
  imports = lib.optionals haveInputsSops [ inputs.sops-nix.homeManagerModules.sops ];

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
    enableDefaultConfig = false;

    settings = {
      "*" = {
        ControlMaster = "auto";
        ControlPersist = "12h";
      };

      "github.com" = {
        User = "git";
        HostName = "github.com";
        IdentityFile = "~/.ssh/githubwhifflash";
        IdentitiesOnly = true;
        Port = 22;
      };

      "vps" = {
        User = "mhr";
        HostName = "wgbsw.vps.webdock.cloud";
        IdentityFile = "~/.ssh/webdockvps";
        IdentitiesOnly = true;
        Port = 22;
      };

      "git.c4rb0n.cloud" = {
        User = "git";
        HostName = "git.c4rb0n.cloud";
        IdentityFile = "~/.ssh/gitea";
        IdentitiesOnly = true;
        Port = 2222;
      };

      "icarus attic.c4rb0n.cloud" = {
        User = "mhr";
        HostName = "10.20.31.41";
        IdentityFile = "~/.ssh/bsw";
        IdentitiesOnly = true;
        Port = 22;
      };

      "luna" = {
        User = "mhr";
        HostName = "10.20.40.20";
        IdentityFile = "~/.ssh/bsw";
        IdentitiesOnly = true;
        Port = 22;
      };

      "poseidon" = {
        User = "mhr";
        HostName = "127.0.0.1";
        ProxyJump = "vps";
        DynamicForward = "1080";
      };
    };

    # Optional: let nix-desktop's gopass helpers pull a key's PASSPHRASE from
    # gopass on first use instead of prompting (see nix-desktop docs/OPTIONS.md).
    # Store the passphrase first — `gopass insert ssh/<name>` — then pin per host:
    #
    # extraConfig = ''
    #   Match host github.com exec "gopass-ssh-load githubwhifflash ssh/github || true"
    #       IdentityFile ~/.ssh/githubwhifflash
    #       IdentitiesOnly yes
    # '';
  };

  # gpg-agent (enabled by the shared gopass module) is the SSH agent.
  services.ssh-agent.enable = false;
}
