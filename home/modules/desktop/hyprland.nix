{ config, pkgs, lib, ... }:

let
  # Per-monitor independent workspaces WITHOUT a plugin (the compiled
  # split-monitor-workspaces plugin is ABI-locked to Hyprland and won't build
  # against our git-main snapshot). Each desk monitor owns a 5-workspace slice
  # of the global pool: HDMI-A-1 → 1-5, DP-3 → 6-10.
  # SUPER+N focuses the focused monitor's Nth workspace; since the two monitors
  # never share a workspace number, switching never drags a workspace across.
  # (The previous version dispatched a Lua-API string to `hyprctl dispatch`,
  # which is not a valid dispatcher — hence it never worked. Fixed to native
  # `workspace`/`movetoworkspace`.)
  # This Hyprland runs a Lua config, so `hyprctl dispatch <x>` evaluates its
  # argument as LUA (`return hl.dispatch(<x>)`), not as a native dispatcher — so
  # we pass Lua expressions (hl.dsp.focus / hl.dsp.window.move), not `workspace N`.
  # Slices are keyed by CONNECTOR NAME, not by left-to-right x-index. The
  # x-index version broke the moment a third monitor appeared: the LG lands at
  # x=0, left of everything, which shifted every other monitor's index by one
  # and silently reassigned all the slices. See the long note in
  # ./hyprlain.nix — same bug, same fix. An output with no slice (the ambient
  # LG, or anything hotplugged later) exits without acting rather than falling
  # back to index 0 and hijacking the main monitor's workspaces.
  wsBases = { "HDMI-A-1" = 0; "DP-3" = 5; };

  sliceCase = ''
    ACTIVE_MON=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.monitor')
    case "$ACTIVE_MON" in
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (out: base: "  ${out}) BASE=${toString base} ;;") wsBases)}
      *) exit 0 ;;
    esac
  '';

  focusWs = pkgs.writeShellScript "hypr-focus-ws" ''
    N=$1
    ${sliceCase}
    hyprctl dispatch "hl.dsp.focus({workspace=$((BASE + N))})"
  '';
  moveToWs = pkgs.writeShellScript "hypr-move-to-ws" ''
    N=$1
    ${sliceCase}
    hyprctl dispatch "hl.dsp.window.move({workspace=$((BASE + N))})"
  '';
in
{
  # The HM Hyprland module points NIX_XDG_DESKTOP_PORTAL_DIR at this user's
  # profile (~/.config/environment.d/10-home-manager.conf →
  # /etc/profiles/per-user/maru/share/xdg-desktop-portal/portals) so it can
  # manage the Hyprland portal via home.packages. Consequently xdg-desktop-portal
  # scans ONLY that dir and ignores the system profile — so the system-level
  # `xdg.portal.extraPortals = [ gtk ]` is invisible to this session and
  # FileChooser (Chromium/Helium "Save as…") has no backend. Install the gtk
  # portal here too so its gtk.portal lands in the dir the frontend actually
  # reads. Without this, only default-folder downloads work; destination pickers
  # silently fail.
  home.packages = [ pkgs.xdg-desktop-portal-gtk ];

  # ...and that alone still wasn't enough: the picker only works once Helium can
  # actually reach the session bus.
  #
  # Nothing in this session exports DBUS_SESSION_BUS_ADDRESS — `systemctl --user
  # show-environment` has no such entry, so every app Hyprland spawns inherits it
  # unset. GLib/GDBus apps don't care: they fall back to $XDG_RUNTIME_DIR/bus on
  # their own, which is why xdg-desktop-portal-gtk itself works fine. Chromium
  # uses libdbus, which does NOT do that fallback — it fails outright with
  # "Could not parse server address: Unknown address type".
  #
  # That breaks the picker via Chromium's dialog chain (shell_dialog_linux.cc):
  # the portal probe is a D-Bus call, so it reports the portal unavailable; the
  # GTK fallback needs libgtk-*.so, which the prebuilt Helium binary dlopens but
  # has on neither its RPATH nor its wrapper's LD_LIBRARY_PATH; so
  # CreateSelectFileDialog returns null and the picker silently does nothing.
  # Downloads to a default path never open a dialog, so those kept working.
  #
  # Verified by A/B: with this unset, triggering a download spawns no portal
  # dialog at all; with it set, the gtk portal's file chooser opens normally.
  # This also un-breaks anything else Chromium needs the bus for on this host —
  # notably --password-store=gnome-libsecret (see modules/desktop/hyprland.nix).
  systemd.user.sessionVariables.DBUS_SESSION_BUS_ADDRESS =
    "unix:path=\${XDG_RUNTIME_DIR}/bus";

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    settings = {
      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        scale = 1;
      };

      mod = {
        _var = "SUPER";
      };

      config = {
        input = {
          kb_layout = "us";
          kb_variant = "altgr-intl";
          follow_mouse = 1;
          sensitivity = 0;
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          layout = "dwindle";
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };
        };
      };

      on = {
        _args = [
          "hyprland.start"
          (lib.generators.mkLuaInline ''
            function()
              hl.exec_cmd("systemctl --user start hyprpolkitagent")
              hl.exec_cmd("waybar")
              hl.exec_cmd("dunst")
              -- Wallpaper: Stylix's hyprpaper target is disabled (see
              -- theme-hyprlain.nix), so this session paints its own wallpaper
              -- with awww (the renamed swww). The sleep lets awww-daemon come up
              -- before `awww img` connects.
              hl.exec_cmd("awww-daemon")
              hl.exec_cmd("sleep 1.5 && awww img ${config.stylix.image}")
              hl.exec_cmd("nm-applet --indicator")
              hl.exec_cmd("equibop")
              hl.exec_cmd("senpai")
              hl.exec_cmd("ferdium")
            end
          '')
        ];
      };

      bind = [
        { _args = [ "SUPER + K"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("kitty")'') ]; }
        { _args = [ "SUPER + Q"      (lib.generators.mkLuaInline "hl.dsp.window.close()") ]; }
        { _args = [ "SUPER + M"      (lib.generators.mkLuaInline "hl.dsp.exit()") ]; }
        { _args = [ "SUPER + S"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("steam")'') ]; }
        { _args = [ "SUPER + H"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("helium")'') ]; }
        { _args = [ "SUPER + D"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("dolphin")'') ]; }
        { _args = [ "SUPER + E"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("equibop")'') ]; }
        { _args = [ "SUPER + C"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("code")'') ]; }
        { _args = [ "SUPER + V"      (lib.generators.mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'') ]; }
        { _args = [ "SUPER + R"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("vicinae toggle")'') ]; }
        { _args = [ "SUPER + L"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("librewolf")'') ]; }

        # Per-monitor workspaces: SUPER+N acts on the focused monitor's own Nth
        # workspace; SHIFT+N moves the window there (see focusWs/moveToWs above).
        { _args = [ "SUPER + 1" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${focusWs} 1")'') ]; }
        { _args = [ "SUPER + 2" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${focusWs} 2")'') ]; }
        { _args = [ "SUPER + 3" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${focusWs} 3")'') ]; }
        { _args = [ "SUPER + 4" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${focusWs} 4")'') ]; }
        { _args = [ "SUPER + 5" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${focusWs} 5")'') ]; }

        { _args = [ "SUPER + SHIFT + 1" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${moveToWs} 1")'') ]; }
        { _args = [ "SUPER + SHIFT + 2" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${moveToWs} 2")'') ]; }
        { _args = [ "SUPER + SHIFT + 3" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${moveToWs} 3")'') ]; }
        { _args = [ "SUPER + SHIFT + 4" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${moveToWs} 4")'') ]; }
        { _args = [ "SUPER + SHIFT + 5" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("${moveToWs} 5")'') ]; }

        { _args = [ "Print" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy")'') ]; }
      ];
    };

    # Mouse binds — written as raw Lua since bindm has no Lua equivalent
    extraConfig = ''
      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      hl.window_rule({ name = "steam-stay-focused", match = { class = "^(steam)$", title = "^()" }, stay_focused = true })
      hl.window_rule({ name = "steam-minsize",      match = { class = "^(steam)$", title = "^()" }, min_size = "1 1" })
    '';
  };
}
