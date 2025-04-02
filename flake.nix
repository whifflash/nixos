{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # impermanence.url = "github:nix-community/impermanence";
    # microvm = {
    #   url = "github:astro/microvm.nix";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";

    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ... } @ inputs:  {
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
      inputs.home-manager.nixosModules.default     
      inputs.stylix.nixosModules.stylix   
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
      inputs.home-manager.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mhr = import ./home/home.nix;
            # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
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
      inputs.home-manager.nixosModules.default          
      ];
    };
  };
}
