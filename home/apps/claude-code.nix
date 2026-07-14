{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  secretName = "zai/api_key";
  secretPath = config.sops.secrets.${secretName}.path;
  claude = pkgs.writeShellApplication {
    name = "claude";
    text = ''
      if [[ ! -r "${secretPath}" ]]; then
        echo "Claude Code: Z.AI API key is unavailable at ${secretPath}" >&2
        exit 1
      fi

      ANTHROPIC_AUTH_TOKEN="$(<"${secretPath}")"
      export ANTHROPIC_AUTH_TOKEN
      exec "${lib.getExe pkgs.claude-code}" "$@"
    '';
  };
in {
  imports = [inputs.sops-nix.homeManagerModules.sops];

  home = {
    packages = [claude];

    file.".claude/settings.json".text = builtins.toJSON {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      env = {
        ANTHROPIC_BASE_URL = "https://api.z.ai/api/anthropic";
        ANTHROPIC_DEFAULT_HAIKU_MODEL = "glm-4.5-air";
        ANTHROPIC_DEFAULT_SONNET_MODEL = "glm-5.2[1m]";
        ANTHROPIC_DEFAULT_OPUS_MODEL = "glm-5.2[1m]";
        CLAUDE_CODE_AUTO_COMPACT_WINDOW = "1000000";
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        API_TIMEOUT_MS = "3000000";
      };
    };
  };

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    secrets.${secretName} = {
      sopsFile = inputs.self + /../secrets/secrets.yaml;
    };
  };
}
