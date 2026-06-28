{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
# taken from: https://gitlab.com/usmcamp0811/dotfiles/-/blob/fb584a888680ff909319efdcbf33d863d0c00eaa/modules/home/apps/firefox/default.nix
with lib;
# with lib.campground;
  let
    # cfg = config.campground.apps.firefox;
    firefox-addons = inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system};
  in {
    # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    #        "video-downloadhelper"
    #      ];

    programs.firefox = {
      configPath = "${config.xdg.configHome}/mozilla/firefox";
      enable = true;
      profiles = {
        default = {
          id = 0;
          name = "default";
          isDefault = true;
          settings = {
            # "browser.startup.homepage" = "https://searx.aicampground.com";
            # "browser.search.defaultenginename" = "Searx";
            # "browser.search.order.1" = "Searx";
          };
          search = {
            force = true;
            default = "google";
            order = ["google"];
            engines = {
              "Nix Packages" = {
                urls = [
                  {
                    template = "https://search.nixos.org/packages";
                    params = [
                      {
                        name = "type";
                        value = "packages";
                      }
                      {
                        name = "query";
                        value = "{searchTerms}";
                      }
                    ];
                  }
                ];
                icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                definedAliases = ["@np"];
              };
              "NixOS Wiki" = {
                urls = [{template = "https://nixos.wiki/index.php?search={searchTerms}";}];
                icon = "https://nixos.wiki/favicon.png";
                updateInterval = 24 * 60 * 60 * 1000; # every day
                definedAliases = ["@nw"];
              };
              bing.metaData.hidden = true;
              google.metaData.alias = "@g"; # builtin engines only support specifying one additional alias
            };
          };
          bookmarks = {
            force = true;
            settings = [
              {
                name = "youtube playlist from all videos";
                url = "javascript:void((function(){var channelID = ytInitialData.metadata.channelMetadataRenderer.externalId;var playlistURL = \"https://www.youtube.com/playlist?list=UU\" + channelID.substr(2);window.location.href = playlistURL;})());";
              }
              # {
              #   name = "gitea homeserver";
              #   url = ''https://'' config.sops.secrets."bsw.servers.gitea.domain".path;
              # }
              {
                name = "wikipedia";
                tags = ["wiki"];
                keyword = "wiki";
                url = "https://en.wikipedia.org/wiki/Special:Search?search=%s&amp;go=Go";
              }
              {
                name = "kernel.org";
                url = "https://www.kernel.org";
              }
              {
                name = "Nix sites";
                toolbar = true;
                bookmarks = [
                  {
                    name = "homepage";
                    url = "https://nixos.org/";
                  }
                  {
                    name = "wiki";
                    tags = ["wiki" "nix"];
                    url = "https://wiki.nixos.org/";
                  }
                ];
              }
            ];
          };
          extensions.packages = with firefox-addons; [
            ublock-origin
            gopass-bridge
            darkreader
            refined-github
            violentmonkey
            privacy-badger
          ];
        };
      };
    };
  }
