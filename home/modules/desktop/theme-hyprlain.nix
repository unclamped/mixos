{ config, pkgs, lib, inputs, ... }:

# Global Hyprlain GTK + Qt theming (applies to BOTH sessions, per user choice).
# Stylix's GTK target is disabled here so it doesn't fight this theme; the rest
# of Stylix (gruvbox base16 for terminals/editors) is left intact.

let
  hl = inputs.hyprlain-src;
  gtkqt = "${hl}/src/gtkqtxdg/src";

  hyprlainGtk = pkgs.runCommand "hyprlain-gtk-theme" { } ''
    mkdir -p $out/share/themes
    cp -r ${gtkqt}/hyprlain $out/share/themes/hyprlain
  '';

  hyprlainIcons = pkgs.runCommand "hyprlaicons" { } ''
    mkdir -p $out/share/icons
    cp -r ${gtkqt}/hyprlaicons $out/share/icons/hyprlaicons
  '';

  qtColorScheme = "${config.home.homeDirectory}/.config/qt6ct/colors/Hyprlain.conf";
in
{
  # Let this module own the GTK look instead of Stylix. Also disable Stylix's
  # GNOME/dconf target (we're on Hyprland, not GNOME) so it doesn't fight the
  # GTK module over dconf interface keys (gtk-theme, icon-theme, font-name…).
  stylix.targets.gtk.enable = false;
  stylix.targets.gnome.enable = false;

  # Don't let Stylix run its own hyprpaper.service to paint the wallpaper. It's
  # WantedBy=graphical-session.target, so it painted the static Stylix image in
  # BOTH sessions regardless of what the session wanted, forcing us to kill it at
  # startup. Instead each session sets its own wallpaper with awww in its start
  # hook (normal → the Stylix image; Hyprlain → the animated Lain GIF).
  stylix.targets.hyprpaper.enable = lib.mkForce false;

  gtk = {
    enable = true;
    theme = {
      name = "hyprlain";
      package = hyprlainGtk;
    };
    iconTheme = {
      name = "hyprlaicons";
      package = hyprlainIcons;
    };
    font = {
      name = "AdwaitaMono Nerd Font";
      size = 11;
    };
  };

  # Ensure GTK4/libadwaita apps also pick up the theme.
  xdg.configFile."gtk-4.0/gtk.css".source = "${gtkqt}/hyprlain/gtk-4.0/gtk.css";

  # ── Qt (qt6ct / qt5ct) — color scheme from upstream, Fusion style ──────────
  xdg.configFile = {
    "qt6ct/colors/Hyprlain.conf".source = "${gtkqt}/qt6ct/Hyprlain.conf";
    "qt5ct/colors/Hyprlain.conf".source = "${gtkqt}/qt5ct/Hyprlain.conf";

    "qt6ct/qt6ct.conf".text = ''
      [Appearance]
      custom_palette=true
      color_scheme_path=${qtColorScheme}
      style=Fusion
      icon_theme=hyprlaicons
      standard_dialogs=default

      [Fonts]
      fixed="AdwaitaMono Nerd Font,11,-1,5,50,0,0,0,0,0"
      general="AdwaitaMono Nerd Font,11,-1,5,50,0,0,0,0,0"
    '';

    "qt5ct/qt5ct.conf".text = ''
      [Appearance]
      custom_palette=true
      color_scheme_path=${config.home.homeDirectory}/.config/qt5ct/colors/Hyprlain.conf
      style=Fusion
      icon_theme=hyprlaicons
      standard_dialogs=default

      [Fonts]
      fixed="AdwaitaMono Nerd Font,11,-1,5,50,0,0,0,0,0"
      general="AdwaitaMono Nerd Font,11,-1,5,50,0,0,0,0,0"
    '';
  };
}
