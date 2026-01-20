{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    
    settings = {
      monitor = ",preferred,auto,1";
      
      exec-once = [
        "waybar"
        "dunst"
        "swww init"
        "nm-applet --indicator"
      ];
      
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
      };
      
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        layout = "dwindle";
      };
      
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
      };
      
      "$mod" = "SUPER";
      
      bind = [
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive"
        "$mod, M, exit"
        "$mod, E, exec, thunar"
        "$mod, V, togglefloating"
        "$mod, R, exec, rofi -show drun"
        
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];
      
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
