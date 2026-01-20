{
  description = "Modular NixOS configuration with Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # Lix - better Nix implementation
    # lix-module = {
    #   url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-1.tar.gz";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
    
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Impermanence
    impermanence.url = "github:nix-community/impermanence";
    
    # Disko for declarative partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Secrets with ragenix
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Stylix for theming
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Hyprland
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, home-manager, impermanence, disko, ragenix, stylix, hyprland, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      username = "maru";
    in
    {
      nixosConfigurations.turing = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username; };
        
        modules = [
          # Core inputs
          # lix-module.nixosModules.default
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          ragenix.nixosModules.default
          stylix.nixosModules.stylix
          
          # Host configuration
          ./hosts/turing
          
          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = { inherit inputs username; };
              users.${username} = import ./home;
            };
          }
        ];
      };
      
      # Development shell for managing secrets
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          age
          ragenix.packages.${system}.default
          nixpkgs-fmt
        ];
      };
    };
}
