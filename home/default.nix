{ config, pkgs, inputs, username, lib, ... }:

{
  imports = [
    # Shell
    ./modules/shell/zsh.nix
    
    # Terminal
    ./modules/terminal/kitty.nix

    # Browsers
    ./modules/browsers/librewolf.nix
    
    # Desktop
    ./modules/desktop/hyprland.nix
    ./modules/desktop/waybar.nix
    ./modules/desktop/rofi.nix
    ./modules/desktop/vicinae.nix
    
    # Editors
    ./modules/editors/neovim.nix

    # nixcord Home Manager module
    inputs.nixcord.homeModules.nixcord

    # Vicinae Home Manager module
    inputs.vicinae.homeManagerModules.default
  ];

  # Home Manager settings
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.05";
    
    # User packages
    packages = with pkgs; [
      # Browsers
      firefox
      
      # Communication
      telegram-desktop
      ferdium
      feishin
      
      # Media
      mpv
      imv
      # Audio / effects
      easyeffects
      
      # Development
      vscode
      # Music apps
      spotify
      millisecond
      
      # Utils
      unzip
      tree
      file

      # Chat / terminal clients
      weechat

      # Games
      steam
    ];
    
    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "librewolf";
      TERMINAL = "kitty";
    };
  };
  
  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # nixcord (Vencord / Equicord) via its Home Manager module
  programs.nixcord = {
    enable = true;
    user = username;
    vesktop.enable = true;
  };
  
  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "unclamped";

        email =
          lib.concatStrings
            (lib.reverseList
              (lib.stringToCharacters "moc.atonatut@0686raelc"));
      };
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };
}
