{ config, pkgs, inputs, ... }:

{
  # Hyprland window manager
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    xwayland.enable = true;
  };
  
  # Enable XDG portal for screen sharing
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
  
  # Display manager
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${pkgs.hyprland}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };
  
  # Graphics drivers (adjust based on your hardware)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  
  # Essential packages for Hyprland
  environment.systemPackages = with pkgs; [
    # Hyprland ecosystem
    waybar
    rofi
    dunst
    swww  # wallpaper daemon
    
    # Screenshots
    grim
    slurp
    
    # Clipboard
    wl-clipboard
    
    # File manager
    kdePackages.dolphin
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
    
    # Network applet
    networkmanagerapplet
    
    # Brightness control
    brightnessctl
    
    # Vicinae (will be installed via home-manager)
    vicinae
  ];
}
