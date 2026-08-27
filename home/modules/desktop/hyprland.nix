{ config, pkgs, lib, ... }:

# The *fallback* Hyprland session — the plain "Hyprland" entry in SDDM's
# session picker, as opposed to the themed "Hyprland (Hyprlain)" one that is
# used day to day (home/modules/desktop/hyprlain). It exists so there is
# always a working session to log into if the Hyprlain config breaks, so it is
# deliberately kept short and boring.
#
# Both hosts import this now. It used to be turing-only, which meant that if
# Hyprlain ever failed on cerf the fallback would have dropped into a stock,
# unconfigured Hyprland.

let
  cfg = config.hyprlandFallback;

  # Per-monitor independent workspaces WITHOUT a plugin (the compiled
  # split-monitor-workspaces plugin is ABI-locked to Hyprland and won't build
  # against our git-main snapshot). Each monitor named in `wsBases` owns a
  # 5-workspace slice of the global pool. SUPER+N focuses the focused
  # monitor's Nth workspace; since two monitors never share a workspace
  # number, switching never drags a workspace across.
  #
  # Slices are keyed by CONNECTOR NAME, not by left-to-right x-index. The
  # x-index version broke the moment a third monitor appeared: the LG lands at
  # x=0, left of everything, which shifted every other monitor's index by one
  # and silently reassigned all the slices. An output with no slice exits
  # without acting rather than falling back to index 0 and hijacking the main
  # monitor's workspaces.
  #
  # This Hyprland runs a Lua config, so `hyprctl dispatch <x>` evaluates its
  # argument as LUA (`return hl.dispatch(<x>)`), not as a native dispatcher —
  # hence we pass Lua expressions, not `workspace N`.
  sliceCase = ''
    ACTIVE_MON=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.monitor')
    case "$ACTIVE_MON" in
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (out: base: "  ${out}) BASE=${toString base} ;;") cfg.wsBases)}
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

  sliced = cfg.wsBases != { };

  wsBind = n:
    { _args = [ "SUPER + ${toString n}" (lib.generators.mkLuaInline
        (if sliced
         then ''hl.dsp.exec_cmd("${focusWs} ${toString n}")''
         else ''hl.dsp.focus({ workspace = "${toString n}" })'')) ]; };
  wsMoveBind = n:
    { _args = [ "SUPER + SHIFT + ${toString n}" (lib.generators.mkLuaInline
        (if sliced
         then ''hl.dsp.exec_cmd("${moveToWs} ${toString n}")''
         else ''hl.dsp.window.move({ workspace = "${toString n}" })'')) ]; };
in
{
  options.hyprlandFallback = {
    wsBases = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      example = { "HDMI-A-1" = 0; "DP-3" = 5; };
      description = ''
        Connector-name → workspace-slice-base map. Empty (the default, and
        right for a single-output laptop) means SUPER+1..5 are plain global
        workspaces.
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra hl.exec_cmd lines for this host's fallback session.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra raw Lua (host-specific binds, window rules) for the fallback session.";
    };
  };

  config = {
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
                -- theme-hyprlain.nix), so this session paints its own
                -- wallpaper with awww (the renamed swww). The sleep lets
                -- awww-daemon come up before `awww img` connects.
                hl.exec_cmd("awww-daemon")
                hl.exec_cmd("sleep 1.5 && awww img ${config.stylix.image}")
                hl.exec_cmd("nm-applet --indicator")
                ${cfg.autostart}
              end
            '')
          ];
        };

        bind = [
          { _args = [ "SUPER + K"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("kitty")'') ]; }
          { _args = [ "SUPER + Q"      (lib.generators.mkLuaInline "hl.dsp.window.close()") ]; }
          { _args = [ "SUPER + M"      (lib.generators.mkLuaInline "hl.dsp.exit()") ]; }
          { _args = [ "SUPER + H"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("helium")'') ]; }
          { _args = [ "SUPER + D"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("dolphin")'') ]; }
          { _args = [ "SUPER + E"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("equibop")'') ]; }
          { _args = [ "SUPER + C"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("code")'') ]; }
          { _args = [ "SUPER + V"      (lib.generators.mkLuaInline ''hl.dsp.window.float({ action = "toggle" })'') ]; }
          { _args = [ "SUPER + R"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("vicinae toggle")'') ]; }
          { _args = [ "SUPER + L"      (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("librewolf")'') ]; }

          # Even the fallback gets the power menu, so the physical power button
          # (which logind is told to ignore — see modules/desktop/power-menu.nix)
          # is never a dead key.
          { _args = [ "SUPER + ESCAPE" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wlogout")'') ]; }
          { _args = [ "XF86PowerOff"   (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("wlogout")'') ]; }

          { _args = [ "Print" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy")'') ]; }
        ]
        ++ map wsBind (lib.range 1 5)
        ++ map wsMoveBind (lib.range 1 5);
      };

      # Mouse binds — written as raw Lua since bindm has no Lua equivalent
      extraConfig = ''
        hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

        ${cfg.extraConfig}
      '';
    };
  };
}
