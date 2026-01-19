{ config, pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    
    # Stylix will theme rofi automatically
    
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Window";
      drun-display-format = "{name}";
      
      # Layout
      width = 40;
      lines = 10;
      columns = 1;
      
      # Position
      location = 0;  # center
      
      # Behavior
      terminal = "kitty";
      sort = true;
      case-sensitive = false;
      cycle = true;
      sidebar-mode = false;
      hover-select = true;
      
      # Appearance
      font = "JetBrainsMono Nerd Font 12";
    };
  };
}
