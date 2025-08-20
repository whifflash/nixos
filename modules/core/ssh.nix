{
  config,
  lib,
  ...
}: {
  programs.ssh = {
    # enable = true;

    # System-wide known_hosts for the daemon & all users
    knownHosts = {
      "icarus 10.20.31.41 attic.c4rb0n.cloud" = {
        hostNames = ["10.20.31.41" "attic.c4rb0n.cloud"];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjph8qyjvqVFPbuCOro4klZjO5X1HZxrWUe32Eja2RH";
      };

      #       knownHosts = {
      #   "icarus 10.20.31.41 attic.c4rb0n.cloud" = {
      #     hostNames = [ "10.20.31.41" ];
      #     publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjph8qyjvqVFPbuCOro4klZjO5X1HZxrWUe32Eja2RH";
      #   };
      # };

      # (optional) gitea ssh host, etc.
      # gitea = {
      #   hostNames = [ "git.c4rb0n.cloud" ];
      #   publicKey = "ssh-ed25519 AAAA...your_gitea_hostkey...";
      # };
    };
  };
}
