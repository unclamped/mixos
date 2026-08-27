{ config, pkgs, lib, ... }:

# Physical power button → the SUPER+ESC power menu, on every host.
#
# By default systemd-logind owns the power key and does HandlePowerKey=poweroff
# — a single press cuts the machine off with no confirmation, which is not what
# a laptop lid-side button should do and is not what the desktop's button
# should do either. Telling logind to ignore it lets the key reach the session
# as XF86PowerOff, where the compositor binds it to the same wlogout overlay
# SUPER+ESC opens (see home/modules/desktop/hyprlain).
#
# A LONG press still forces a hard poweroff, which is the escape hatch when the
# session is wedged and no menu will appear.

{
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";

    # Suspend key (some keyboards have one) keeps its normal meaning.
    HandleSuspendKey = "suspend";

    # Lid: suspend on close, which is the default, stated explicitly so it is
    # obvious this file owns the whole logind key/lid policy.
    #
    # Lid OPEN is not a logind action at all — the machine resumes because the
    # firmware treats the lid as a wake source, which it does correctly here
    # (journal on cerf: "Lid opened" immediately followed by "ACPI: PM: Waking
    # up from system sleep state S3"). If the screen stays black after opening
    # the lid, the fault is on the compositor side, not here; see the DPMS note
    # in home/modules/desktop/hyprlain/default.nix.
    HandleLidSwitch = "suspend";
    # Docked / on an external monitor, closing the lid should not suspend.
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # wlogout has to exist system-wide, not just in the user profile, so the
  # fallback session and a rescue shell can both reach it.
  environment.systemPackages = [ pkgs.wlogout ];
}
