{ config, pkgs, ... }:

{
  # Use the Hyprlain vicinae theme below instead of Stylix's generated one.
  stylix.targets.vicinae.enable = false;

  programs.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 1;
      };
    };
    settings = {
      close_on_focus_loss = true;
      consider_preedit = true;
      pop_to_root_on_close = true;
      search_files_in_root = true;
      font = {
        normal = {
          size = 12;
          family = "Maple Nerd Font";
        };
      };
      # Vicinae is the launcher for the Hyprlain session (SUPER+SPACE). Use the
      # Hyprlain palette for both light/dark so it matches that session.
      theme = {
        dark.name = "hyprlain";
        light.name = "hyprlain";
      };
    };

    # Hyprlain palette theme (generated to ~/.config/vicinae/themes/hyprlain.toml)
    themes.hyprlain = {
      meta = {
        version = 1;
        name = "Hyprlain";
        description = "Serial Experiments Lain — pink/gold on black";
        variant = "dark";
      };
      colors = {
        core = {
          background = "#000000";
          foreground = "#C1B48E";
          secondary_background = "#1A1A1A";
          border = "#CE7688";
          accent = "#CE7688";
        };
        accents = {
          blue = "#965363";
          green = "#BA6A7B";
          magenta = "#CE7688";
          orange = "#C1B48E";
          purple = "#A05969";
          red = "#CE7688";
          yellow = "#C1B48E";
          cyan = "#804654";
        };
      };
    };
  };
}