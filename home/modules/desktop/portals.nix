{ config, pkgs, lib, ... }:

# Portal plumbing every Hyprland session on every host needs. This used to
# live inside home/modules/desktop/hyprland.nix (which is turing's *fallback*
# session config), so cerf — which never imported that file — silently didn't
# have it, and its Helium/Chromium "Save as…" pickers failed the same way
# turing's used to.

{
  # The HM Hyprland module points NIX_XDG_DESKTOP_PORTAL_DIR at this user's
  # profile (~/.config/environment.d/10-home-manager.conf →
  # /etc/profiles/per-user/maru/share/xdg-desktop-portal/portals) so it can
  # manage the Hyprland portal via home.packages. Consequently
  # xdg-desktop-portal scans ONLY that dir and ignores the system profile — so
  # the system-level `xdg.portal.extraPortals = [ gtk ]` is invisible to this
  # session and FileChooser (Chromium/Helium "Save as…") has no backend.
  # Install the gtk portal here too so its gtk.portal lands in the dir the
  # frontend actually reads. Without this, only default-folder downloads work;
  # destination pickers silently fail.
  home.packages = [ pkgs.xdg-desktop-portal-gtk ];

  # ...and that alone still wasn't enough: the picker only works once Helium
  # can actually reach the session bus.
  #
  # Nothing in this session exports DBUS_SESSION_BUS_ADDRESS — `systemctl
  # --user show-environment` has no such entry, so every app Hyprland spawns
  # inherits it unset. GLib/GDBus apps don't care: they fall back to
  # $XDG_RUNTIME_DIR/bus on their own, which is why xdg-desktop-portal-gtk
  # itself works fine. Chromium uses libdbus, which does NOT do that fallback —
  # it fails outright with "Could not parse server address: Unknown address
  # type".
  #
  # That breaks the picker via Chromium's dialog chain (shell_dialog_linux.cc):
  # the portal probe is a D-Bus call, so it reports the portal unavailable; the
  # GTK fallback needs libgtk-*.so, which the prebuilt Helium binary dlopens
  # but has on neither its RPATH nor its wrapper's LD_LIBRARY_PATH; so
  # CreateSelectFileDialog returns null and the picker silently does nothing.
  # Downloads to a default path never open a dialog, so those kept working.
  #
  # Verified by A/B: with this unset, triggering a download spawns no portal
  # dialog at all; with it set, the gtk portal's file chooser opens normally.
  # This also un-breaks anything else Chromium needs the bus for on this host —
  # notably --password-store=gnome-libsecret.
  systemd.user.sessionVariables.DBUS_SESSION_BUS_ADDRESS =
    "unix:path=\${XDG_RUNTIME_DIR}/bus";
}
