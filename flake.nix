{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    hyprland.url = "github:hyprwm/Hyprland";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ... } @ inputs:  {
    nixosConfigurations.nixbox = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs;
      hostName = "nixbox";
      WM = "sway"; };
      system = "x86_64-linux";
      modules = [ 
                  ./hosts/decafbad-vm/configuration.nix
                  ./modules/modules.nix  
                  inputs.home-manager.nixosModules.default          
                ];
    };
    nixosConfigurations.mia = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs;
      hostName = "mia";
      WM = "sway"; };
      system = "x86_64-linux";
      modules = [ 
                  ./hosts/mia/configuration.nix
                  ./modules/modules.nix  
                  inputs.home-manager.nixosModules.default          
                ];
    };
    nixosConfigurations.nixboxmia = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs;
      hostName = "mianixbox";
      WM = "sway"; };
      system = "x86_64-linux";
      modules = [ 
                  ./hosts/mia-nixbox/configuration.nix
                  ./modules/modules.nix  
                  inputs.home-manager.nixosModules.default          
                ];
    };
    nixosConfigurations.luna = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs;
      hostName = "luna";
      WM = "sway"; };
      system = "x86_64-linux";
      modules = [ 
                  ./hosts/luna/configuration.nix
                  ./modules/modules.nix  
                  inputs.home-manager.nixosModules.default          
                ];
    };
  };
}
