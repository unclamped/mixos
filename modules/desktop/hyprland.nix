{ config, pkgs, inputs, ... }:

# NOTE on interlaced modes — deliberately NOT patched here.
#
# Hyprland's modeline parser (src/config/shared/monitor/Parser.cpp:72)
# lowercases every flag token before the lookup, but the flag map keys the
# interlace bit as "Interlace" with a capital I, so DRM_MODE_FLAG_INTERLACE is
# unreachable no matter how the modeline is written. That is a genuine upstream
# bug and was still present on main as of 2026-08-19.
#
# It is not worth patching on this host. Overriding the package is a cache miss
# on the Hyprland binary cache, so the compositor gets rebuilt from source on
# every change — and fixing the parser would not buy anything anyway: this GPU
# is a GTX 1660 SUPER (Turing, TU116), and NVIDIA dropped interlaced display
# output on Turing and later. That is why the kernel already filters the
# EDID-advertised 1024x768i out of /sys/class/drm/card0-DP-*/modes. The parser
# typo is worth reporting upstream; it is not worth carrying a local rebuild
# for.

{
  # Universal Wayland Session Manager. Wraps compositors in proper systemd user
  # units so the graphical session, its env, and cleanup are managed by systemd.
  # This also silences Hyprland's "not started via start-hyprland/uwsm" warning
  # and fixes teardown on logout (the compositor's user units are stopped
  # cleanly instead of leaving a dangling VT at a blinking cursor).
  programs.uwsm.enable = true;

  # Hyprland window manager
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    xwayland.enable = true;
    # Launch the normal Hyprland session through uwsm (adds a uwsm-wrapped
    # wayland-session entry the display manager offers).
    withUWSM = true;
  };
  
  # Secret Service provider (org.freedesktop.secrets) — without this, any app
  # that saves to "the keyring" (browsers' native password store, Chromium's
  # gnome-libsecret backend, etc.) silently fails: there's no daemon to talk
  # to. The module already sets enableGnomeKeyring on the "login" PAM
  # service; SDDM's own PAM rules substack "login" (see sddm.nix), so the
  # keyring auto-unlocks with your login password there too, without
  # needing a separate enableGnomeKeyring on the "sddm" service itself.
  services.gnome.gnome-keyring.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    # Portal backend routing. The `*` wildcard used to leave FileChooser
    # unresolved on Hyprland: xdg-desktop-portal-gtk advertises `UseIn=gnome`,
    # so the deprecated UseIn matching never selects it under
    # XDG_CURRENT_DESKTOP=Hyprland, and the wildcard only fell back to lazy
    # D-Bus activation of the (dead) gtk backend — a cold-start race that made
    # Chromium/Helium "save as…" pickers silently fail from a fresh boot.
    #
    # Route each interface explicitly with an ordered preference list:
    #   - `common.default` is the fallback for other desktops → gtk.
    #   - `hyprland.default` applies to this session (matches XDG_CURRENT_DESKTOP
    #     lowercased). hyprland handles Screenshot/ScreenCast/GlobalShortcuts;
    #     FileChooser/OpenURI fall through to gtk since hyprland doesn't
    #     implement them.
    config = {
      common.default = [ "gtk" ];
      hyprland.default = [ "hyprland" "gtk" ];
    };
  };
  
  # Display manager is provided by ../desktop/sddm-hyprlain.nix (SDDM with the
  # Hyprlain theme). Both the normal and Hyprlain Hyprland sessions are listed
  # in the session picker.

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
    awww  # wallpaper daemon
    
    # Screenshots
    grim
    slurp
    
    # Clipboard
    wl-clipboard
    
    # File manager
    kdePackages.dolphin
    kdePackages.qtstyleplugin-kvantum
    kdePackages.kio
    kdePackages.kio-fuse
    kdePackages.kio-extras
    
    # Network applet
    networkmanagerapplet
    
    # Brightness control
    brightnessctl
    
    # Vicinae (will be installed via home-manager)
    vicinae

    hyprpolkitagent
  ];
}
