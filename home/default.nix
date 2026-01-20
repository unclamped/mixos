{ config, pkgs, inputs, username, lib, ... }:

{
  imports = [
    # Shell
    ./modules/shell/zsh.nix
    
    # Terminal
    ./modules/terminal/kitty.nix
    
    # Desktop
    ./modules/desktop/hyprland.nix
    ./modules/desktop/waybar.nix
    ./modules/desktop/rofi.nix
    
    # Editors
    ./modules/editors/neovim.nix
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
      discord
      telegram-desktop
      
      # Media
      mpv
      imv
      
      # Development
      vscode
      
      # Utils
      unzip
      tree
      file
      
      # Vicinae for Hyprland window management
      vicinae
    ];
    
    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "firefox";
      TERMINAL = "kitty";
    };
  };
  
  # Let Home Manager manage itself
  programs.home-manager.enable = true;
  
  # Git configuration
  programs.git = {
    enable = true;
    userName = "unclamped";

    userEmail =
      lib.concatStrings
        (lib.reverseList
          (lib.stringToCharacters "moc.atonatut@0686raelc"));

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };
}
