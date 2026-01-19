#!/usr/bin/env bash

# NixOS Dotfiles Setup Script
# Run this from your Arch system to prepare the repository

set -e

REPO_DIR="${HOME}/.dotfiles"

echo "=== NixOS Dotfiles Setup ==="
echo ""

# Check if directory exists
if [ -d "$REPO_DIR" ]; then
    echo "⚠️  Directory $REPO_DIR already exists!"
    read -p "Remove it and continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting."
        exit 1
    fi
    rm -rf "$REPO_DIR"
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$REPO_DIR"/{hosts/main,modules/{core,services,desktop,hardware},home/modules/{shell,terminal,desktop,editors},home/packages,secrets,lib}

cd "$REPO_DIR"

# Initialize git
echo "🔧 Initializing git repository..."
git init
git branch -M main

# Get user information
echo ""
echo "📝 Please provide some information:"
read -p "Your name: " USER_NAME
read -p "Your email: " USER_EMAIL
read -p "Your desired username: " USERNAME

# Create flake.nix
echo "📄 Creating flake.nix..."
cat > flake.nix << 'FLAKE_EOF'
{
  description = "Modular NixOS configuration with Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/2.91.1-1.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    impermanence.url = "github:nix-community/impermanence";
    
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    hyprland.url = "github:hyprwm/Hyprland";
  };

  outputs = { self, nixpkgs, lix-module, home-manager, impermanence, disko, ragenix, stylix, hyprland, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      username = "USERNAME_PLACEHOLDER";
    in
    {
      nixosConfigurations.main = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username; };
        
        modules = [
          lix-module.nixosModules.default
          disko.nixosModules.disko
          impermanence.nixosModules.impermanence
          ragenix.nixosModules.default
          stylix.nixosModules.stylix
          
          ./hosts/main
          
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
      
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          age
          ragenix.packages.${system}.default
          nixpkgs-fmt
        ];
      };
    };
}
FLAKE_EOF

# Replace username placeholder
sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" flake.nix

# Create .gitignore
echo "🚫 Creating .gitignore..."
cat > .gitignore << 'GITIGNORE_EOF'
result
result-*
secrets/*.txt
secrets/*.key
*.age.key
hosts/*/hardware.nix
*.swp
*.swo
*~
.DS_Store
.direnv/
.envrc
GITIGNORE_EOF

# Create placeholder files for all modules
echo "📝 Creating module files..."

# Copy all the configuration files here
# (This would be too long to include inline, so in practice you'd 
# want to either download from a template repo or have the files
# prepared separately)

echo ""
echo "✅ Repository structure created!"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo ""
echo "1. Copy all the module files from the artifacts into $REPO_DIR"
echo "2. Update the following files with your information:"
echo "   - home/default.nix (git config)"
echo "   - modules/core/users.nix (your name)"
echo ""
echo "3. Identify your secondary SSD:"
echo "   lsblk"
echo "   Then edit hosts/main/disko.nix and change the device path"
echo ""
echo "4. Commit your changes:"
echo "   cd $REPO_DIR"
echo "   git add ."
echo "   git commit -m 'Initial NixOS configuration'"
echo ""
echo "5. (Optional) Push to GitHub:"
echo "   git remote add origin https://github.com/$USERNAME/dotfiles.git"
echo "   git push -u origin main"
echo ""
echo "6. Follow INSTALLATION_GUIDE.md to install NixOS"
echo ""
echo "📚 Repository location: $REPO_DIR"

# Set git config in the repo
cd "$REPO_DIR"
git config user.name "$USER_NAME"
git config user.email "$USER_EMAIL"

echo ""
echo "🎉 Setup complete! Check INSTALLATION_GUIDE.md for next steps."
