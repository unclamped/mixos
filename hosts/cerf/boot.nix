{ config, pkgs, inputs, ... }:

{
  # Bootloader configuration. Unlike turing, this ESP is SHARED with Windows
  # Boot Manager (mounted, never formatted — see fileSystems."/boot" in
  # default.nix). systemd-boot auto-detects bootmgfw.efi on a shared ESP with
  # no extra config, so Windows keeps showing up in the boot menu.
  #
  # The ESP is only 100M and the disk is fully partitioned edge-to-edge (no
  # free space to grow it — confirmed via `lsblk`: ESP -> MSR -> Windows C:
  # -> Windows recovery -> LUKS, back to back). A single NixOS generation's
  # kernel+initrd is already ~35M, and Windows's own files take ~27M, so
  # even configurationLimit = 2 doesn't reliably fit (this is what caused
  # bootloader installs to fail with ENOSPC). Keep only 1 generation.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 1;
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

}
