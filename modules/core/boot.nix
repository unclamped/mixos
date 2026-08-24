{ config, pkgs, inputs, ... }:

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
      "loglevel=3"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      # Meta Quest 2 Link cable (vendor:product 2833:5013) fails USB3 U1 link
      # power management negotiation on this board's xHCI controller, causing
      # repeated disconnects. Disabling LPM for this device fixes it.
      "usbcore.quirks=2833:5013:k"
      # Test: firmware denies OS control of ASPM on this board (writes to
      # /sys/module/pcie_aspm/parameters/policy fail with EPERM), so force
      # ASPM off at the kernel level to rule it out as a contributor to the
      # remaining (post-LPM-fix) USB disconnects.
      "pcie_aspm=off"
      # LG T730SH CRT on DP-1, via a two-stage DP->HDMI->VGA adapter chain.
      # Pin its mode at the DRM level so that everything running BEFORE the
      # Hyprland session -- plymouth, the console, the SDDM greeter -- drives it
      # correctly too. hyprland.lua's rule cannot help any of those.
      #
      # @75 specifically, and the reason is not refresh rate but SYNC POLARITY.
      # A CRT selects its deflection preset from the H/V sync polarity pair, and
      # this monitor's 1024x768 modes split:
      #     @85  94.50 MHz  +hsync +vsync  -> right geometry, but 94.5 MHz is
      #                                       more than the converters hold
      #                                       sync at, so it flickers
      #     @75  78.75 MHz  +hsync +vsync  -> right geometry, stable
      #     @70/@60         -hsync -vsync  -> wrong preset, image lands in a
      #                                       sub-rectangle of the raster
      # An earlier `video=DP-1:1024x768@60` here is what made the console and
      # plymouth render offset: DMT 1024x768@60 is negative-sync. The kernel
      # does honour this parameter (modetest showed the resulting mode tagged
      # `type: userdef`) and resolves it against the DMT table, so @75 lands on
      # DMT 0x12 with the positive polarity we want.
      #
      # This also addresses a boot hang: with no mode pinned, the LG comes up at
      # its EDID-preferred @85 and flickers, and a DRM connector flapping
      # through connect/disconnect stalled plymouth at switch-root for ~84s
      # (journal: an 84s gap between "Reached target Initrd Default Target" and
      # the next plymouthd signal). A mode the display can actually hold should
      # stop the churn.
      "video=DP-1:1024x768@75"
    ];
    
    # Plymouth boot splash — Lain-themed via modules/desktop/plymouth-lain.nix
    # (static logo, TV-static animation during the LUKS passphrase prompt).
    plymouth = {
      enable = true;
    };
    
    # Support for BTRFS
    supportedFilesystems = [ "btrfs" ];
    
    # Tmp on tmpfs for speed
    tmp.useTmpfs = true;

    initrd.systemd.enable = true;
    initrd.systemd.emergencyAccess = true;
  };
}
