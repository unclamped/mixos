{ config, pkgs, inputs, ... }:

{
  # Bootloader configuration. Unlike turing, this ESP is SHARED with Windows
  # Boot Manager (mounted, never formatted — see fileSystems."/boot" in
  # default.nix). systemd-boot auto-detects bootmgfw.efi on a shared ESP with
  # no extra config, so Windows keeps showing up in the boot menu.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false; # disable editor for security
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      timeout = 5; # a bit longer than turing's: give Windows selection time too
    };

    kernelPackages = pkgs.linuxPackages_latest;

    kernelParams = [
      "loglevel=3"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    plymouth.enable = true;

    supportedFilesystems = [ "btrfs" ];
    tmp.useTmpfs = true;

    initrd.systemd.enable = true;
    initrd.systemd.emergencyAccess = true;
  };

  # Same Lain plymouth logo as turing, over Stylix's tested plymouth theme
  # (correctly renders the LUKS passphrase prompt on an encrypted system).
  stylix.targets.plymouth.logo =
    "${inputs.hyprlain-src}/src/hyprland/src/assets/media/imgs/lainsmall2.png";
}
