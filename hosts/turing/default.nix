{ config, pkgs, inputs, username, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    
    # Core modules
    ../../modules/core/boot.nix
    ../../modules/core/impermanence.nix
    ../../modules/core/networking.nix
    ../../modules/core/users.nix
    
    # Services
    ../../modules/services/pipewire.nix
    
    # Desktop
    ../../modules/desktop/hyprland.nix

    # ENVIDIA
    ../../modules/hardware/nvidia.nix
  ];

  # Fix Lix separateDebugInfo issue
  # nix.package = pkgs.lix.override {
  #   separateDebugInfo = false;
  # };

  # Hostname
  networking.hostName = "nixos";

  # Timezone and locale
  time.timeZone = "America/Argentina/Cordoba";
  i18n.defaultLocale = "en_US.UTF-8";
  
  # Console keymap
  console.keyMap = "us";

  # Enable flakes
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;

  # Stylix theming
  stylix = {
    enable = true;
    
    # You can use a wallpaper or a base16 scheme
    # Using wallpaper (it will generate colors from it)
    image = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/master/wallpapers/nix-wallpaper-dracula.png";
      sha256 = "SykeFJXCzkeaxw06np0QkJCK28e0k30PdY8ZDVcQnh4=";
    };
    
    # Or use a base16 scheme directly
    # base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    
    polarity = "dark";
    
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      
      sizes = {
        applications = 11;
        terminal = 12;
        desktop = 10;
        popups = 11;
      };
    };
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    # System tools
    vim
    wget
    curl
    git
    htop
    btop
    xterm
    
    # File management
    ranger
    fzf
    ripgrep
    fd
    
    # BTRFS tools
    btrfs-progs
    compsize
  ];

  # Enable CUPS for printing (optional)
  # services.printing.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Don't change this unless you know what you're doing.
  system.stateVersion = "24.05";
}
