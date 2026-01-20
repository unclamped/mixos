{ config, pkgs, ... }:

{
  # Bootloader configuration
  boot = {
    # Use systemd-boot (since you're already using it on Arch)
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;  # Keep last 10 generations
        editor = false;  # Disable editor for security
      };
      
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      
      timeout = 3;
    };
    
    # Latest kernel
    kernelPackages = pkgs.linuxPackages_latest;
    
    # Kernel parameters
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
    
    # Plymouth for boot splash (optional)
    plymouth = {
      enable = true;
    };
    
    # Support for BTRFS
    supportedFilesystems = [ "btrfs" ];
    
    # Tmp on tmpfs for speed
    tmp.useTmpfs = true;
  };
}
