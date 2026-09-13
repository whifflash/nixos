{
  config,
  inputs,
  ...
}:
{
  # Renders the Gitea personal access token (secrets/gitea-token.yaml, key
  # `token`) into the env file that nix-desktop's repo-sync instances source at
  # run time (`[repoSync.gitea].environmentFile` in the host's config.toml).
  # Shared by the Linux and macOS home configs; hosts without a [repoSync]
  # section simply never read the file.
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets."gitea/token" = {
      sopsFile = inputs.self + /secrets/gitea-token.yaml;
      format = "yaml";
      key = "token";
      mode = "0400";
    };

    templates."gitea.env" = {
      content = ''
        TOKEN=${config.sops.placeholder."gitea/token"}
      '';
      path = "${config.home.homeDirectory}/.config/sops-nix/templates/gitea.env";
      mode = "0400";
    };
  };
}
