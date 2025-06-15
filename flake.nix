{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixpkgs = { url = "github:nixos/nixpkgs/nixos-25.05"; };
    # unstable = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # stylix.url = "github:danth/stylix/release-24.11";
    # stylix.inputs.nixpkgs.follows = "nixpkgs";
    # disko.url = "github:nix-community/disko";
    # disko.inputs.nixpkgs.follows = "nixpkgs";
    # nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    # nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # firefox-addons.url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
    # firefox-addons.inputs.nixpkgs.follows = "nixpkgs";

    # impermanence.url = "github:nix-community/impermanence";
    # microvm = {
    #   url = "github:astro/microvm.nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # nur.url = "github:nix-community/NUR";

  };

  outputs = { self, nixpkgs, home-manager, sops-nix, nur, ... }@inputs:  {


    nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
      specialArgs = { 
        inherit inputs;
        hostname = "nixbox";
        wm = "sway";
        user = "mhr"; 
      };
      system = "x86_64-linux";
      modules = [ 
      ./hosts/decafbad-vm/configuration.nix
      ./modules/modules.nix  
      sops-nix.nixosModules.sops
      ];
    };
    nixosConfigurations.mia = nixpkgs.lib.nixosSystem {
      specialArgs = { 
        inherit inputs;
        hostname = "mia";
        wm = "sway";
        user = "mhr";
      };
      system = "x86_64-linux";
      modules = [ 
      ./hosts/mia/configuration.nix
      ./modules/modules.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.mhr = import ./home/home.nix;

            home-manager.extraSpecialArgs = {
            inherit inputs;
            };
      }
      ];
    };
    nixosConfigurations.nixboxmia = nixpkgs.lib.nixosSystem {
      specialArgs = { 
        inherit inputs;
        hostname = "mianixbox";
        wm = "sway";
        user = "mhr";
      };
      system = "x86_64-linux";
      modules = [ 
      ./hosts/mia-nixbox/configuration.nix
      ./modules/modules.nix  
      inputs.home-manager.nixosModules.default          
      ];
    };
    nixosConfigurations.luna = nixpkgs.lib.nixosSystem {
      specialArgs = { 
        inherit inputs;
        hostname = "luna";
        wm = "sway";
        user = "mhr";
      };
      system = "x86_64-linux";
      modules = [ 
      ./hosts/luna/configuration.nix
      ./modules/modules.nix
      inputs.sops-nix.nixosModules.sops
      inputs.home-manager.nixosModules.home-manager
      {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.users.mhr = import ./home/home.nix;

            home-manager.extraSpecialArgs = {
            inherit inputs;
            };
      }
      ];
    };
  };
}
