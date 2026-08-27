{ config, pkgs, lib, ... }:

# cerf's Hyprlain session: the EliteBook 840 G2's single built-in panel.
#
# Everything visual/behavioural that cerf shares with turing lives in
# home/modules/desktop/hyprlain — this file only supplies what is genuinely
# specific to a laptop: one output, a battery module, touchpad gestures, a
# shorter idle-to-suspend leash, and the split keyboard layout below.

{
  hyprlain = {
    enable = true;
    description = "cerf (EliteBook 840 G2, single eDP panel), Hyprland Lua config";

    # 13.0 rather than turing's 14.0: this is a 14" 1366x768 panel, so the
    # desk's font size costs a visible number of columns.
    kitty.fontSize = "13.0";

    # Battery machine: don't let it sit awake all night if it's left unplugged.
    idle.suspendTimeout = 900;

    waybar = {
      # Only one output, so no filter; narrower margins because 1366px of bar
      # can't spare 80px of inset.
      margin = 20;
      modulesRight = [ "mpris" "pulseaudio" "network" "battery" "clock" "group/hiddentray" "custom/power" ];
      workspaceIcons = ''
        "1": "",  "2": "",  "3": "",
        "4": "󰲦", "5": "󰲨", "6": "󰲪",
        "7": "󰲬", "8": "󰲮", "9": "",
        "urgent": "",
        "focused": "",
        "default": ""
      '';
      # No "thermal-zone" pin here: unlike turing's board, this one's zone
      # numbering isn't stable enough to hardcode, so let waybar pick.
      extraModules = ''
        "battery": {
          "states": { "warning": 30, "critical": 15 },
          "format": "{icon} {capacity}%",
          "format-charging": " {capacity}%",
          "format-icons": ["", "", "", "", ""],
          "tooltip-format": "{time} remaining"
        },
      '';
    };

    lua = {
      browser = "helium";
      popupClasses = "feh|mpv|pureref|qalculate|iwgtk|desktop-portal|missioncenter|wireshark|gns3|virt-manager";

      # Just the built-in panel. The wildcard rule picks up whatever is
      # connected, so an external monitor plugged in later gets the same
      # "preferred/auto" treatment rather than being ignored.
      monitors = ''
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      '';

      # ── Two keyboard layouts, at the same time ───────────────────────────
      #
      # The requirement is per-DEVICE, not per-session: the built-in keyboard
      # is a Latin-American (la-latin1) unit, while anything plugged into USB
      # is a US board that wants the international/AltGr-dead-keys layout.
      #
      # A two-entry `kb_layout = "us,latam"` would NOT do this — that gives
      # every keyboard the same ordered pair plus a switch key, so the two
      # keyboards can never disagree and you end up toggling constantly.
      # Hyprland's per-device config is the mechanism that actually splits
      # them: the global input block below stays "us"/"altgr-intl" (so every
      # keyboard Hyprland has never heard of, i.e. every external one, gets
      # that), and the one rule here overrides the internal AT keyboard.
      #
      # "at-translated-set-2-keyboard" is the internal keyboard's name as
      # Hyprland reports it — verify with `hyprctl devices` if a kernel update
      # ever renames it. "latam" is the XKB layout that corresponds to the
      # console's la-latin1 keymap (set in hosts/cerf/default.nix).
      kbLayout = "us";
      kbVariant = "altgr-intl";
      devices = ''
        hl.device({
          name       = "at-translated-set-2-keyboard",
          kb_layout  = "latam",
          kb_variant = "",
        })
      '';

      # Laptop touchpad: tap-to-click and natural scrolling, which turing's
      # mouse obviously doesn't want.
      touchpad = ''disable_while_typing = false, middle_button_emulation = true, tap_to_click = true, natural_scroll = true'';

      gestures = ''
        hl.gesture({
          fingers = 3,
          direction = "horizontal",
          action = "workspace",
        })
      '';

      # Single monitor, so SUPER+N is the plain global workspace switch — no
      # per-monitor slice arithmetic needed.
      workspaceBinds = ''
        for i = 1, 9 do
          hl.bind(M .. " + " .. i,         hl.dsp.focus({ workspace = tostring(i) }))
          hl.bind(M .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
        end
      '';
    };
  };
}
