{inputs, ...}: {
  programs.ssh = {
    # enable = true;

    # System-wide known_hosts for the daemon & all users
    knownHosts = {
      builder = {
        hostNames = ["10.20.31.41" "attic.c4rb0n.cloud"];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMjph8qyjvqVFPbuCOro4klZjO5X1HZxrWUe32Eja2RH";
      };
    };
  };

  sops.secrets."ssh/builder_ed25519" = {
    sopsFile = inputs.self + /secrets/ssh.yaml;
    format = "yaml";
    key = "bsw/priv";
    owner = "root";
    group = "root";
    mode = "0400";
    path = "/root/.ssh/builder_ed25519";
  };
}
