{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # hyprland.url = "github:hyprwm/Hyprland";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
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
      ];
    };
    nixosConfigurations.mia = nixpkgs.lib.nixosSystem {
      specialArgs = { 
        inherit inputs;
        hostname = "mia";
        wm = "hyprland";
        user = "mhr";
      };
      system = "x86_64-linux";
      modules = [ 
      ./hosts/mia/configuration.nix
      ./modules/modules.nix
      inputs.home-manager.nixosModules.default
      # make home-manager as a module of nixos
      # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
      inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.mhr = import ./home.nix;
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
