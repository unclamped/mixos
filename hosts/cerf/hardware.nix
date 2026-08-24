# Real hardware detection from `nixos-generate-config --root /mnt` on the
# EliteBook 840 G2, trimmed down to ONLY hardware detection. fileSystems,
# swapDevices, and boot.initrd.luks.devices are deliberately NOT here — disko
# (hosts/cerf/disko.nix) already generates all of those from the same
# partition/subvolume layout, and duplicating them here (which is what the raw
# nixos-generate-config output does, since it ran after disko already mounted
# everything) causes conflicting-definition errors at eval time.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
