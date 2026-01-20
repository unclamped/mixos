{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        
        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "network" "cpu" "memory" "battery" "tray" ];
        
        "hyprland/workspaces" = {
          format = "{icon}";
          on-click = "activate";
          format-icons = {
            "1" = "一";
            "2" = "二";
            "3" = "三";
            "4" = "四";
            "5" = "五";
            "6" = "六";
            "7" = "七";
            "8" = "八";
            "9" = "九";
            "10" = "十";
          };
        };
        
        "hyprland/window" = {
          format = "{}";
          max-length = 50;
        };
        
        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d, %Y (%R)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };
        
        cpu = {
          format = " {usage}%";
          tooltip = false;
        };
        
        memory = {
          format = " {}%";
        };
        
        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-plugged = " {capacity}%";
          format-alt = "{icon} {time}";
          format-icons = [ "" "" "" "" "" ];
        };
        
        network = {
          format-wifi = " {essid}";
          format-ethernet = " {ipaddr}";
          format-linked = " {ifname} (No IP)";
          format-disconnected = "⚠ Disconnected";
          tooltip-format = "{ifname}: {ipaddr}/{cidr}";
        };
        
        pulseaudio = {
          format = "{icon} {volume}%";
          format-bluetooth = "{icon} {volume}%";
          format-bluetooth-muted = " {icon}";
          format-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };
        
        tray = {
          spacing = 10;
        };
      };
    };
    
    # Stylix will handle styling, but you can add custom CSS
    style = ''
      * {
        font-size: 14px;
        font-family: "JetBrainsMono Nerd Font";
      }
      
      window#waybar {
        background-color: rgba(30, 30, 46, 0.9);
        border-radius: 0;
      }
      
      #workspaces button {
        padding: 0 10px;
        border-radius: 0;
      }
      
      #workspaces button.active {
        background-color: rgba(137, 180, 250, 0.3);
      }
    '';
  };
}
