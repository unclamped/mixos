# xrizer: OpenVR->OpenXR shim for SteamVR-only games, since OpenComposite is
# unmaintained. Registers itself as the OpenVR runtime; WiVRn's own OpenXR
# runtime registration is handled by the system module (modules/gaming/vr.nix).
{ config, pkgs, ... }:
{
  xdg.configFile."openvr/openvrpaths.vrpath".text = builtins.toJSON {
    config = [ "${config.xdg.dataHome}/Steam/config" ];
    external_drivers = null;
    jsonid = "vrpathreg";
    log = [ "${config.xdg.dataHome}/Steam/logs" ];
    runtime = [ "${pkgs.xrizer}/lib/xrizer" ];
    version = 1;
  };
}
