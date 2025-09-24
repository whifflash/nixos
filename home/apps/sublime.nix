# home/apps/sublime.nix
{ lib, pkgs, config, inputs ? {}, ... }:
let
  haveInputsSops = inputs ? sops-nix;
  isDarwin = pkgs.stdenv.isDarwin;

  sublimeBaseDir =
    if isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Sublime Text"
    else
      "${config.xdg.configHome}/sublime-text";

  licensePath = "${sublimeBaseDir}/Local/License.sublime_license";
  userDir     = "${sublimeBaseDir}/Packages/User";
in
{
  imports = lib.optionals haveInputsSops [ inputs.sops-nix.homeManagerModules.sops ];

  config = lib.mkMerge [
    {
      # Linux: install Sublime via Nix; macOS: skip (use Homebrew cask).
      home.packages = lib.optionals (!isDarwin) [ pkgs.sublime4 ];

      # Package Control wants the User dir seeded
      home.file."${userDir}/Package Control.sublime-settings".text = ''
        {
          "installed_packages": [
            "Package Control",
            "Nix",
            "Gruvbox"
          ]
        }
      '';

      home.file."${userDir}/Preferences.sublime-settings".text = ''
        {
          "font_size": 14,
          "ensure_newline_at_eof_on_save": true,
          "trim_trailing_white_space_on_save": true,
          "translate_tabs_to_spaces": true,
          "tab_size": 2,
          "highlight_modified_tabs": true,
          "show_tab_close_buttons": true,
          "ignored_packages": []
        }
      '';

      # Harmless on Linux; Sublime ignores platform-mismatch files
      home.file."${userDir}/Default (OSX).sublime-keymap".text = ''
        [
          { "keys": ["super+shift+t"], "command": "reopen_last_file" }
        ]
      '';
    }

    (lib.mkIf haveInputsSops {
      sops = {
        age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        secrets."sublime/license" = {
          sopsFile = inputs.self + /../secrets/sublime.yaml;
          path = licensePath;
        };
      };
    })
  ];
}
