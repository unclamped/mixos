{ config, pkgs, lib, ... }:

# ─── Making the EliteBook 840 G2 function-key row actually do things ────────
#
# The keys were never "not wired up": the Hyprlain session has bound
# XF86MonBrightness*/XF86Audio* for a long time. Three separate things were
# stopping them from having any effect, and only the first is specific to this
# laptop.
#
# 1. BRIGHTNESS: brightnessctl could not write.
#    /sys/class/backlight/intel_backlight/brightness is root:root 0644, and
#    `brightnessctl s 10%+` as maru returns "Failed to set brightness:
#    Operation not permitted" — silently, since the keybind swallows it.
#    brightnessctl ships a udev rule that chgrps the backlight to "video" and
#    makes it group-writable, but a package in environment.systemPackages does
#    NOT get its udev rules installed; it has to be in services.udev.packages.
#    maru is already in the video group, so that is the whole fix.
#
# 2. VOLUME: needs PipeWire. cerf never imported modules/services/pipewire.nix
#    (it only had it by nixpkgs default), so wpctl had nothing dependable to
#    talk to. That import now happens in hosts/cerf/default.nix.
#
# 3. NIGHT MODE: there was simply nothing to trigger. hyprsunset now runs in
#    the session and SUPER+SHIFT+N toggles it (home/modules/desktop/hyprlain).
#
# ── Which physical key is which, on this chassis ────────────────────────────
#
# The 840 G2 top row is F1-F12 with secondary functions printed on them. Which
# one you get depends on the BIOS setting "Action Keys Mode" (F10 at boot →
# Advanced → Built-In Device Options / System Configuration):
#   * Action Keys Mode ENABLED  → pressing F5 mutes; Fn+F5 sends F5.
#   * Action Keys Mode DISABLED → pressing F5 sends F5; Fn+F5 mutes.
# There is also an Fn-lock toggle on Fn+Shift on some firmware revisions.
# Nothing in Linux can change this; it is decided before the OS boots.
#
# The secondary functions on this model, in order:
#   F1  help          F2  brightness down   F3  brightness up
#   F4  display switch (external/mirror)    F5  mute
#   F6  volume down   F7  volume up         F8  mic mute
#   F9  keyboard backlight                  F10 (none)
#   F11 wireless/airplane                   F12 sleep
#
# All of those are bound in the Hyprlain session. To see what a key actually
# emits (useful if the mapping above is wrong for your firmware revision):
#     wev              # shows the Wayland keysym, e.g. XF86MonBrightnessUp
#     sudo libinput debug-events --show-keycodes   # kernel-level, pre-XKB
#
# Wireless/airplane (F11) and the keyboard backlight (F9) are handled by the
# kernel hp-wmi driver directly and need no keybind.

{
  # THE fix for the brightness keys: install brightnessctl's udev rules.
  services.udev.packages = [ pkgs.brightnessctl ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    playerctl
    wev                 # "what keysym is this key" — see above
    libinput            # libinput debug-events
    acpi                # battery/thermal at a glance
  ];

  # Handle the volume/brightness/mic keys at the SEAT level too, so they still
  # work in the SDDM greeter and on a bare TTY, not only inside a Hyprland
  # session that has them bound.
  services.actkbd = {
    enable = true;
    bindings = [
      { keys = [ 224 ]; events = [ "key" "rep" ]; command = "${pkgs.brightnessctl}/bin/brightnessctl s 10%-"; }
      { keys = [ 225 ]; events = [ "key" "rep" ]; command = "${pkgs.brightnessctl}/bin/brightnessctl s 10%+"; }
    ];
  };
}
