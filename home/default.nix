{ config, pkgs, inputs, username, lib, ... }:

# ─── Shared Home Manager base ───────────────────────────────────────────────
#
# Imported by BOTH host profiles (home/hosts/turing, home/hosts/cerf). It owns
# everything that is true of "maru's desktop" regardless of which machine it is
# running on: shell, terminal, browsers, the Hyprlain session, theming, the
# launcher/bar/menu, the editor, and the identity bits (git, ssh public key).
#
# Anything that differs between machines belongs in the host profile, NOT here,
# and preferably as an option on a shared module rather than a second copy of
# the module. The previous layout — home/default.nix for turing and a
# hand-maintained home/cerf.nix beside it — is exactly what this replaces: the
# two had already drifted (different stateVersion, different Python, one had
# the portal fix and the other didn't).

{
  imports = [
    # Shell
    ./modules/shell/zsh.nix

    # Terminal
    ./modules/terminal/kitty.nix

    # Browsers
    ./modules/browsers/browsers.nix

    # Desktop
    ./modules/desktop/portals.nix
    ./modules/desktop/hyprland.nix        # the plain fallback session
    ./modules/desktop/hyprlain            # the themed session used day to day
    ./modules/desktop/theme-hyprlain.nix
    ./modules/desktop/waybar.nix
    ./modules/desktop/rofi.nix
    ./modules/desktop/vicinae.nix

    # Editors
    ./modules/editors/neovim.nix

    # Apps
    ./modules/apps/nixcord.nix            # Discord / Equibop, Lain-themed

    # Vicinae Home Manager module
    inputs.vicinae.homeManagerModules.default
  ];

  home = {
    username = username;
    homeDirectory = "/home/${username}";

    # Matches system.stateVersion on both hosts. This was 26.05 on turing and
    # 26.11 on cerf, which is the kind of drift the split above is meant to
    # stop; both machines are 26.11 installs.
    stateVersion = "26.11";

    # Packages every machine gets. Machine-specific ones (games, VR, IDA,
    # networking labs) live in the host profile.
    packages = with pkgs; [
      # Browsers
      firefox

      # Editors / dev
      vscode

      # Notes — synced between hosts by Syncthing, see modules/services/syncthing.nix
      obsidian

      # Media
      mpv
      imv

      # KDE apps
      ark

      # Utils
      unzip
      tree
      file
    ];

    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "helium";
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

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

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

  # The shared id_ed25519 keypair's public half — non-secret, so declared here
  # instead of relying on it being manually copied between hosts. The private
  # half is ragenix-managed, see modules/core/users.nix's ssh-id-ed25519
  # secret. Must match the key authorized in each host's services.openssh
  # config.
  #
  # The comment field (an email) is stored reversed, same as the git email
  # above, so it doesn't sit in cleartext in the repo.
  home.file.".ssh/id_ed25519.pub".text =
    let
      email = lib.concatStrings (lib.reverseList (lib.stringToCharacters "moc.atonatut@0686raelc"));
    in
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDiPiksIGtarfrN0IPEOlOBIpi4qX+M1J/DWPoxexviq ${email}\n";
}
