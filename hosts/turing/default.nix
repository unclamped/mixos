{ config, pkgs, inputs, username, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    
    # Core modules
    ../../modules/core/boot.nix
    ../../modules/core/impermanence.nix
    ../../modules/core/networking.nix
    ../../modules/core/users.nix
    
    # Services
    ../../modules/services/pipewire.nix
    ../../modules/services/docker.nix
    
    # Desktop
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/hyprlain-session.nix
    ../../modules/desktop/sddm-hyprlain.nix
    ../../modules/desktop/helium-policy.nix
    ../../modules/desktop/plymouth-lain.nix

    # ENVIDIA
    ../../modules/hardware/nvidia.nix

    # Gaming
    ../../modules/gaming/steam.nix
    ../../modules/gaming/minecraft.nix
    ../../modules/gaming/vr.nix

    # FIDO2 / U2F hardware tokens
    ../../modules/hardware/fido2.nix

    # for my Lemokey Keychron keeb
    # ../../modules/hardware/qmk.nix
  ];

  # Hostname
  networking.hostName = "nixos";

  # Timezone and locale
  time.timeZone = "America/Argentina/Cordoba";
  services.timesyncd.enable = true;
  environment.variables.TZDIR = "/etc/zoneinfo";
  i18n.defaultLocale = "en_US.UTF-8";
  
  # Console keymap
  console.keyMap = "us";

  # Enable flakes
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [ "https://hyprland.cachix.org" "https://attic.xuyh0120.win/lantian" ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.flake.setFlakeRegistry = true;

  # TODO: vesktop-1.6.5 pulls pnpm-10.29.2 (insecure); check if a newer vesktop
  # release fixes this before removing the allowance.
  nixpkgs.config.permittedInsecurePackages = [ "pnpm-10.29.2" ];

  # Use the nix-cachyos kernel exposed by the overlay (preferred pinned overlay)
  boot.kernelPackages = pkgs.lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;

  # Dolphin: removable media / automount support
  services.udisks2.enable = true;

  security.polkit.enable = true;

  # Qt platform theme: qt5ct/qt6ct so the global Hyprlain Qt color scheme
  # (home/modules/desktop/theme-hyprlain.nix) applies to Qt apps like Dolphin.
  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };

  # Stylix theming
  stylix = {
    enable = true;
    
    # You can use a wallpaper or a base16 scheme
    # Using wallpaper (it will generate colors from it)
    image = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/master/wallpapers/nix-wallpaper-dracula.png";
      sha256 = "SykeFJXCzkeaxw06np0QkJCK28e0k30PdY8ZDVcQnh4=";
    };
    
    # Global base16 scheme: the Lain "Wired" palette (derived from the Hyprlain
    # theme colors). Recolors everything Stylix owns — terminals, editor, GTK
    # fallbacks, both sessions — to pink-on-black, so the whole system reads as
    # Lain instead of gruvbox. Apps with bespoke Hyprlain theming (spicetify,
    # vicinae, GTK/Qt) have their Stylix targets disabled elsewhere so they win.
    base16Scheme = ./lain-base16.yaml;
    
    polarity = "dark";

    targets.qt.enable = false;
    
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      
      sizes = {
        applications = 11;
        terminal = 12;
        desktop = 10;
        popups = 11;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    # System tools
    vim
    wget
    curl
    git
    htop
    btop
    xterm
    
    # File management
    ranger
    fzf
    ripgrep
    fd
    
    # BTRFS tools
    btrfs-progs
    compsize
  
    # Misc
    variety

    claude-code
    antigravity

    ferdium
    senpai
    signal-desktop
    simplex-chat-desktop
    zulip
    fluffychat

    xonotic

    pnpm

    nodejs

    # Python package/project manager. uv's own downloaded CPython builds are
    # generic dynamically linked binaries that NixOS can't exec, so we also
    # provide python312 from nixpkgs for uv to use (e.g. for browser-use).
    uv
    # Drop the `doc` passthru: environment.extraOutputsToInstall pulls in "doc",
    # and cpython's doc output currently fails to build (Sphinx 9.1 breakage).
    # Removing the passthru is build-input-invariant, so `out` stays cache-hit.
    (python312.overrideAttrs (old: {
      passthru = builtins.removeAttrs old.passthru [ "doc" ];
    }))

    krita
    feh
    swappy
    imv
    krita
    inkscape

    glow

    ffmpeg

    libimobiledevice
    ifuse # optional, to mount using 'ifuse'
  ];

  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  # Enable CUPS for printing (optional)
  # services.printing.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Don't change this unless you know what you're doing.
  system.stateVersion = "26.11";
}
