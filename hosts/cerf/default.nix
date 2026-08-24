{ config, pkgs, inputs, username, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ./boot.nix

    # Core modules
    ../../modules/core/impermanence.nix
    ../../modules/core/networking.nix
    ../../modules/core/users.nix

    # Services
    ../../modules/services/docker.nix

    # Desktop
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/hyprlain-session.nix
    ../../modules/desktop/sddm-hyprlain.nix
    ../../modules/desktop/helium-policy.nix
    ../../modules/desktop/plymouth-lain.nix

    # FIDO2 / U2F hardware tokens — useful on a security-focused machine
    ../../modules/hardware/fido2.nix
  ];

  # Hostname
  networking.hostName = "cerf";

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

  # Lix, from nixpkgs itself rather than the git.lix.systems flake (see the
  # comment in flake.nix) — Hydra-built and cached, no from-source compile.
  nix.package = pkgs.lix;

  # The existing Windows ESP, mounted (never formatted) at /boot. Windows
  # Boot Manager lives here; systemd-boot auto-detects and lists it.
  # Confirmed via blkid on the real hardware — this is the FAT32 filesystem
  # UUID, not a partlabel (Windows didn't set the "System" partlabel here).
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A84C-A32B";
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # Dolphin: removable media / automount support
  services.udisks2.enable = true;

  # The built-in Synaptics touchpad (TM2768-001) runs over SMBus/RMI4
  # (upstream deliberately enabled this for the EliteBook 840 G2 — it gives
  # smoother movement and proper 3-finger gestures vs. plain PS/2). That
  # path has a known kernel resume bug though: after any suspend/resume the
  # touchpad goes dead and stays dead (confirmed via `journalctl -k`:
  # "Failed to read current IRQ mask", "Resume failed with code -6",
  # repeating on every subsequent suspend attempt too). Re-probing the
  # SMBus driver binding for the device (i2c-0/0-002c, per
  # /proc/bus/input/devices) after resume recovers it without giving up
  # SMBus mode.
  powerManagement.resumeCommands = ''
    dev="0-002c"
    driver="/sys/bus/i2c/drivers/rmi4_smbus"
    if [ -e "$driver/$dev" ]; then
      sleep 1
      echo -n "$dev" > "$driver/unbind" || true
      sleep 0.5
      echo -n "$dev" > "$driver/bind" || true
    fi
  '';

  security.polkit.enable = true;

  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };

  # Stylix theming — same Lain palette as turing, so both machines read as
  # one system.
  stylix = {
    enable = true;

    image = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/NixOS/nixos-artwork/master/wallpapers/nix-wallpaper-dracula.png";
      sha256 = "SykeFJXCzkeaxw06np0QkJCK28e0k30PdY8ZDVcQnh4=";
    };

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

  # Wireshark: capture without running as root (adds maru to the wireshark
  # group and sets dumpcap's capabilities instead of setuid-root).
  programs.wireshark.enable = true;
  users.users.${username}.extraGroups = [ "wireshark" ];

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

    # ── Networking / CCNAv7 / cybersec ──────────────────────────────────────
    wireshark
    tshark
    nmap
    tcpdump
    mtr
    traceroute
    iperf3
    netcat-gnu
    whois
    dig # bind's dnsutils
    ethtool
    usbutils # lsusb — handy for USB-serial console cables
    picocom # serial console access to real Cisco gear
    minicom
    openvpn
    wireguard-tools
    gns3-gui
    gns3-server
    dynamips

    # Misc
    unzip
    tree
    file
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. Don't change this unless you know what you're doing.
  system.stateVersion = "26.11";
}
