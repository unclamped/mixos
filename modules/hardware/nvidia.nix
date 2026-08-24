{ config, pkgs, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];
  
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';

  systemd.services.nvidia-pcie-power-fix = {
    description = "Set NVIDIA GPU PCIe power to on before shutdown";
    wantedBy = [ "shutdown.target" "reboot.target" ];
    before = [ "shutdown.target" "reboot.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "bash -c 'echo on > /sys/bus/pci/devices/$(lspci -D | grep -i nvidia | head -1 | cut -d\" \" -f1)/power/control'";
    };
  };

  # Enable Wayland for NVIDIA
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
