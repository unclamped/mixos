{ config, pkgs, inputs, username, lib, ... }:

# Home Manager profile for cerf — the CCNAv7/CompSci/cybersec/networking
# laptop. Deliberately leaner than home/default.nix (turing): no VR, no
# spicetify/nixcord/ida-pro, no turing-desk-specific Hyprland config. Shares
# the generic HM modules (shell, terminal, browsers, waybar/rofi/vicinae,
# theme, neovim) and gets its own single-monitor Hyprlain session.

{
  imports = [
    # Shell
    ./modules/shell/zsh.nix

    # Terminal
    ./modules/terminal/kitty.nix

    # Browsers
    ./modules/browsers/browsers.nix

    # Desktop — Hyprlain session (single-monitor laptop adaptation) plus the
    # generic pieces shared with turing (theming, launcher, bar, app menu).
    ./modules/desktop/hyprlain-laptop.nix
    ./modules/desktop/theme-hyprlain.nix
    ./modules/desktop/waybar.nix
    ./modules/desktop/rofi.nix
    ./modules/desktop/vicinae.nix

    # Editors
    ./modules/editors/neovim.nix

    # Vicinae Home Manager module
    inputs.vicinae.homeManagerModules.default
  ];

  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";

    packages = with pkgs; [
      # Browsers
      firefox

      # Development
      vscode

      # Networking / CCNAv7 / cybersec extras beyond the system package set
      # (modules/hardware/net tools are installed system-wide in
      # hosts/cerf/default.nix; these are user-facing/GUI or scripting tools)
      python312
      python312Packages.scapy
      remmina # RDP/VNC/SSH client — useful for reaching lab VMs
      filezilla

      # KDE apps
      ark

      # Utils
      unzip
      tree
      file
    ];

    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "librewolf";
      TERMINAL = "kitty";
    };
  };

  xdg.configFile."kdeglobals".text = ''
    [General]
    TerminalApplication=kitty
    TerminalService=kitty.desktop
  '';

  xdg.dataFile."applications/nvim.desktop".text = ''
    [Desktop Entry]
    Name=Neovim
    GenericName=Text Editor
    Exec=kitty -e nvim %F
    Terminal=false
    Type=Application
    Categories=Utility;TextEditor;
    MimeType=text/plain;text/x-nix;text/markdown;text/css;text/javascript;application/json;application/toml;application/x-yaml;
    Icon=nvim
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory"    = [ "org.kde.dolphin.desktop" ];
      "text/plain"         = [ "nvim.desktop" ];
      "text/x-nix"         = [ "nvim.desktop" ];
      "text/markdown"      = [ "nvim.desktop" ];
      "text/css"           = [ "nvim.desktop" ];
      "text/javascript"    = [ "nvim.desktop" ];
      "application/json"   = [ "nvim.desktop" ];
      "application/toml"   = [ "nvim.desktop" ];
      "application/x-yaml" = [ "nvim.desktop" ];
    };
  };

  programs.home-manager.enable = true;

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

  # Same key as turing's home/default.nix — see the comment there. Must
  # match the key authorized below in this host's services.openssh config.
  home.file.".ssh/id_ed25519.pub".text =
    let
      email = lib.concatStrings (lib.reverseList (lib.stringToCharacters "moc.atonatut@0686raelc"));
    in
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDiPiksIGtarfrN0IPEOlOBIpi4qX+M1J/DWPoxexviq ${email}\n";
}
