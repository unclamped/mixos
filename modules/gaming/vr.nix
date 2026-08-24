# Tethered Quest 2 VR: WiVRn as the OpenXR runtime (USB-tunnelled via `adb
# reverse`), WayVR as its home/dashboard application, xrizer as the
# OpenVR->OpenXR shim for SteamVR-only games (see home/modules for the
# openvrpaths.vrpath wiring).
{ pkgs, ... }:
{
  services.wivrn = {
    enable = true;
    autoStart = true;

    # WiVRn now manages its own active OpenXR runtime registration; Steam's
    # PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES is set system-wide so Steam's
    # sandboxed games can find it too.
    steam.importOXRRuntimes = true;

    config = {
      enable = true;
      json.application = [ pkgs.wayvr ];
    };
  };

  # `adb` (for the USB-tethered `adb reverse` tunnel to the Quest 2). Uaccess
  # udev rules for the ADB USB interface are handled automatically by systemd.
  environment.systemPackages = [ pkgs.android-tools ];
}
