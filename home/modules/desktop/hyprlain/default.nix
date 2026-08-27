{ config, pkgs, lib, inputs, ... }:

# ─── The Hyprlain session, as ONE module shared by every host ───────────────
#
# This replaces the old home/modules/desktop/hyprlain.nix (turing) and
# hyprlain-laptop.nix (cerf) pair, which were ~80% byte-identical copies that
# had already drifted apart (different hypridle timeouts, different waybar
# icon encodings, a dpms bug fixed in neither).
#
# Everything that is genuinely the same on every machine — the palette, the
# dunst/hyprlock/wlogout look, the keybind vocabulary, the waybar skeleton —
# lives here exactly once. Everything that is legitimately per-machine is an
# OPTION, set from home/hosts/<host>.nix. If you find yourself wanting to copy
# this file again: add an option instead.

let
  cfg = config.hyprlain;

  # Assets from the Hyprlain upstream repo, hashed into flake.lock.
  hlSrc  = inputs.hyprlain-src;
  assets = "${hlSrc}/src/hyprland/src/assets";

  wallpaperGif = "${assets}/media/anim/bg_dark_anim_0_08.gif";
  lockWall     = "${assets}/media/imgs/lain_wall.png";

  # The characteristic Lain "eye" — used as the waybar tray/stats drawer toggle
  # (custom/expand) instead of a plain Nerd-Font eye glyph.
  eyeIcon      = "${assets}/media/anim/icons/WiredLogIn.gif";

  # Wlogout GIF icons
  iconLock     = "${assets}/media/anim/icons/laintrain.gif";
  iconLogout   = "${assets}/media/anim/icons/VisLain.gif";
  iconSuspend  = "${assets}/media/anim/icons/SunD.gif";
  iconHibern   = "${assets}/media/anim/icons/cxc4.gif";
  iconShutdown = "${assets}/media/anim/icons/acid.gif";
  iconReboot   = "${assets}/media/anim/icons/aether-preview-02.gif";

  # Kitty theme colours (from upstream src/hyprland/src/kitty/current-theme.conf)
  kittyColors = ''
    foreground            #C1B48E
    background            #000000
    selection_foreground  #000000
    selection_background  #CE7688
    url_color             #CE7688
    cursor                #CE7688
    cursor_text_color     #000000
    active_border_color   #CE7688
    inactive_border_color #804654
    active_tab_foreground   #000000
    active_tab_background   #CE7688
    inactive_tab_foreground #C1B48E
    inactive_tab_background #1A1A1A
    color0  #000000
    color8  #5D333C
    color1  #CE7688
    color9  #BA6A7B
    color2  #C1B48E
    color10 #B5A985
    color3  #A49978
    color11 #968C6E
    color4  #A05969
    color12 #965363
    color5  #8E4E5D
    color13 #804654
    color6  #897F63
    color14 #7A7158
    color7  #C1B48E
    color15 #6F3D49
  '';

  palette-conf = ''
    $backprimary   = 000000
    $backsecondary = 1A1A1A
    $backtertiary  = 2A2A2A
    $backquaternary = 3A3A3A
    $backquinary   = 4A4A4A
    $backsenary    = 5A5A5A
    $backseptenary = 6A6A6A
    $backoctonary  = 7A7A7A
    $backnonary    = 8A8A8A
    $backdecenary  = 9A9A9A
    $backundenary  = AAAAAA
    $backduodenary = BABABA

    $foreprimary   = CE7688
    $foresecondary = BA6A7B
    $foretertiary  = A05969
    $forequaternary = 965363
    $forequinary   = 8E4E5D
    $foresenary    = 804654
    $foreseptenary = 6F3D49
    $foreoctonary  = 5D333C
    $forenonary    = 49272F
    $foredecenary  = 381E24
    $foreundenary  = 2A171B
    $foreduodenary = 1D0F12

    $highprimary   = C1B48E
    $highsecondary = B5A985
    $hightertiary  = A49978
    $highquaternary = 968C6E
    $highquinary   = 897F63
    $highsenary    = 7A7158
    $highseptenary = 69614C
    $highoctonary  = 5A5341
    $highnonary    = 4E4838
    $highdecenary  = 403C2E
    $highundenary  = 332F24
    $highduodenary = 221F18
  '';

  palette-css = ''
    @define-color backprimary   #000000;
    @define-color backsecondary #1A1A1A;
    @define-color backtertiary  #2A2A2A;
    @define-color backquaternary #3A3A3A;
    @define-color backquinary   #4A4A4A;
    @define-color backsenary    #5A5A5A;
    @define-color backseptenary #6A6A6A;
    @define-color backoctonary  #7A7A7A;
    @define-color backnonary    #8A8A8A;
    @define-color backdecenary  #9A9A9A;
    @define-color backundenary  #AAAAAA;
    @define-color backduodenary #BABABA;

    @define-color foreprimary   #CE7688;
    @define-color foresecondary #BA6A7B;
    @define-color foretertiary  #A05969;
    @define-color forequaternary #965363;
    @define-color forequinary   #8E4E5D;
    @define-color foresenary    #804654;
    @define-color foreseptenary #6F3D49;
    @define-color foreoctonary  #5D333C;
    @define-color forenonary    #49272F;
    @define-color foredecenary  #381E24;
    @define-color foreundenary  #2A171B;
    @define-color foreduodenary #1D0F12;

    @define-color highprimary   #C1B48E;
    @define-color highsecondary #B5A985;
    @define-color hightertiary  #A49978;
    @define-color highquaternary #968C6E;
    @define-color highquinary   #897F63;
    @define-color highsenary    #7A7158;
    @define-color highseptenary #69614C;
    @define-color highoctonary  #5A5341;
    @define-color highnonary    #4E4838;
    @define-color highdecenary  #403C2E;
    @define-color highundenary  #332F24;
    @define-color highduodenary #221F18;
  '';

  # Paths the session's own configs live at, referenced from binds, autostart
  # and hypridle alike. Kept in one place so a rename can't half-apply.
  hyprDir   = "$HOME/.config/hypr-hyprlain";
  wlogoutCmd = "wlogout -l ${hyprDir}/wlogout-layout -C ${hyprDir}/wlogout.css";

  # ── DPMS, correctly ──────────────────────────────────────────────────────
  # THIS is the fix for "opening the lid leaves the screen black".
  #
  # The Hyprlain session runs a LUA config, and under a Lua config `hyprctl
  # dispatch <x>` evaluates its argument as Lua (it literally becomes
  # `return hl.dispatch(<x>)`) rather than as a native dispatcher. So the
  # `hyprctl dispatch dpms on` that hypridle's after_sleep_cmd used to run
  # was never a no-op-with-a-warning, it was a hard Lua syntax error:
  #
  #   error: 3 [string "return hl.dispatch(dpms on)"]:1: ')' expected near 'on'
  #
  # i.e. the panel was switched off on suspend and NOTHING ever switched it
  # back on. Pressing the power button "fixed" it only because that keypress
  # is an input event, which wakes hypridle and runs its on-resume hooks.
  #
  # Note also that the dispatcher validates its argument as a TABLE: passing
  # a bare string (hl.dsp.dpms('on')) reports "ok" and does nothing at all,
  # which is exactly how this stayed hidden. Verified on cerf against
  # Hyprland 0.56.0: only the {on=...} form actually moves dpmsStatus.
  dpmsOn  = ''hyprctl dispatch "hl.dsp.dpms({on=true})"'';
  dpmsOff = ''hyprctl dispatch "hl.dsp.dpms({on=false})"'';

  # Waybar module definitions that every host shows. Host-specific ones
  # (battery on a laptop, custom/eq on turing) come from waybar.extraModules.
  waybarCommonModules = ''
        "hyprland/window": {
          "format": " {title} ",
          "separate-outputs": true
        },
        "pulseaudio": {
          "format": "{icon}",
          "format-bluetooth": "{icon}{volume}%",
          "format-muted": "",
          "format-icons": {
            "default": ["", ""],
            "speaker": ["", ""],
            "speaker-muted": "",
            "headphone": "",
            "hands-free": "󱡏",
            "headset": "󰋎",
            "phone": "",
            "phone-muted": "",
            "portable": "",
            "car": ""
          },
          "scroll-step": 1,
          "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
          "max-volume": 150,
          "tooltip-format": "{icon} {volume}% — scroll to change, click to mute"
        },
        "mpris": {
          "format": "{player_icon} {title}",
          "format-paused": "{status_icon} {title}",
          "player-icons": { "default": "", "spotify": "" },
          "status-icons": { "paused": "" },
          "max-length": 28,
          "on-click": "playerctl play-pause",
          "on-scroll-up": "playerctl next",
          "on-scroll-down": "playerctl previous",
          "tooltip-format": "{title} — {artist}"
        },
        "network": {
          "family": "ipv4",
          "format-ethernet": "󰈀",
          "format-wifi": "{icon}",
          "format-linked": "󱘖",
          "format-disconnected": "󰤮",
          "format-icons": ["󰤫", "󰤯", "󰤟", "󰤢", "󰤥", "󰤨"],
          "on-click-right": "iwgtk",
          "tooltip-format": "{icon} {signalStrength}% [{essid} - {ifname}] {frequency}GHz\n{ipaddr}/{cidr}\nUP[{bandwidthUpBits}] DWN[{bandwidthDownBits}]\nGATEWAY: {gwaddr}",
          "format-alt": "{icon} {signalStrength}%"
        },
        "clock": {
          "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
          "format-alt": "{:%Y-%m-%d}"
        },
        "custom/expand": {
          "format": " ",
          "tooltip": "Show cpu / temp / memory / tray"
        },
        "cpu": {
          "format": "",
          "tooltip": true,
          "format-icons": ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"],
          "on-click-right": "hyprsysteminfo"
        },
        "memory": {
          "format": "",
          "tooltip": true,
          "tooltip-format": "{used:0.1f}/{total}GiB\t[{percentage}%]\n{swapUsed:0.1f}/{swapTotal}GiB\t[{swapPercentage}%]",
          "on-click-right": "missioncenter"
        },
        "tray": {
          "icon-size": 16,
          "show-passive-items": true,
          "smooth-scrolling-threshold": 1.0,
          "spacing": 10
        },
        "custom/power": {
          "format": "⏻",
          "tooltip": false,
          "on-click": "${wlogoutCmd}"
        }
  '';

  # Night mode toggle. hyprsunset is a daemon; `hyprctl hyprsunset` talks to
  # it. There is no built-in "toggle", so remember the state in a runtime file
  # and flip between the configured warm temperature and 6500K (identity).
  hyprsunsetToggle = pkgs.writeShellScriptBin "hyprsunset-toggle" ''
    set -u
    state="''${XDG_RUNTIME_DIR:-/tmp}/hyprlain-nightmode"
    if [ -e "$state" ]; then
      hyprctl hyprsunset temperature 6500
      rm -f "$state"
      ${pkgs.libnotify}/bin/notify-send -a Hyprlain "Night mode off" "6500K" || true
    else
      hyprctl hyprsunset temperature 3500
      : > "$state"
      ${pkgs.libnotify}/bin/notify-send -a Hyprlain "Night mode on" "3500K" || true
    fi
  '';

  jsonList = xs: "[" + lib.concatMapStringsSep ", " (x: ''"${x}"'') xs + "]";
in
{
  options.hyprlain = {
    enable = lib.mkEnableOption "the Hyprlain Hyprland session";

    description = lib.mkOption {
      type = lib.types.str;
      default = "generated by home-manager";
      description = "One-line comment written at the top of hyprland.lua.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Host-specific packages the session needs (dashboards, debug tools).";
    };

    kitty = {
      fontSize = lib.mkOption {
        type = lib.types.str;
        default = "14.0";
        description = "font_size for the session-scoped kitty (kitty-hyprlain/kitty.conf).";
      };
      extraSettings = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra lines appended to the session-scoped kitty config. This is a
          SEPARATE file from programs.kitty's, so host overrides that must
          apply to both have to be set in both places.
        '';
      };
    };

    idle = {
      dimTimeout     = lib.mkOption { type = lib.types.int; default = 150; description = "Seconds before the backlight dims."; };
      lockTimeout    = lib.mkOption { type = lib.types.int; default = 300; description = "Seconds before the session locks."; };
      dpmsTimeout    = lib.mkOption { type = lib.types.int; default = 330; description = "Seconds before the displays switch off."; };
      suspendTimeout = lib.mkOption { type = lib.types.int; default = 1800; description = "Seconds before the machine suspends."; };
      blacklist = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra [[node_blacklist]] stanzas for wayland-pipewire-idle-inhibit.
          Any node that streams CONTINUOUSLY (an always-on filter chain, say)
          must go here, or it pins the idle inhibitor on forever and the
          machine never suspends.
        '';
      };
    };

    waybar = {
      outputs = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Restrict the bar to these outputs; null means every output.";
      };
      margin = lib.mkOption { type = lib.types.int; default = 40; description = "Symmetric left/right bar margin in px."; };
      modulesRight = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "mpris" "pulseaudio" "network" "clock" "group/hiddentray" "custom/power" ];
      };
      workspaceIcons = lib.mkOption {
        type = lib.types.lines;
        description = "JSON body of hyprland/workspaces' format-icons.";
      };
      temperature = lib.mkOption {
        type = lib.types.lines;
        default = ''
          "critical-threshold": 80,
          "format": "{icon}",
          "format-critical": "{temperatureC}°C {icon}",
          "format-icons": ["", "", "", ""],
          "on-click-right": "missioncenter"
        '';
        description = "JSON body of the temperature module (thermal-zone differs per board).";
      };
      extraModules = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra module definitions, as JSON object entries ending in a comma.";
      };
      extraStyle = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra CSS appended to the bar stylesheet."; };
    };

    lua = {
      monitors = lib.mkOption {
        type = lib.types.lines;
        default = ''hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })'';
        description = "hl.monitor(...) calls describing this host's outputs.";
      };
      workspaceRules = lib.mkOption { type = lib.types.lines; default = ""; description = "hl.workspace_rule(...) calls."; };
      kbLayout  = lib.mkOption { type = lib.types.str; default = "us"; description = "Default XKB layout for keyboards with no per-device rule."; };
      kbVariant = lib.mkOption { type = lib.types.str; default = "altgr-intl"; description = "Default XKB variant."; };
      touchpad = lib.mkOption {
        type = lib.types.lines;
        default = ''disable_while_typing = false, middle_button_emulation = true, tap_to_click = false'';
        description = "Body of the input.touchpad table.";
      };
      devices = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          hl.device(...) calls. This is how a host gives ONE keyboard its own
          XKB layout while every other keyboard keeps the global one.
        '';
      };
      gestures = lib.mkOption { type = lib.types.lines; default = ""; description = "hl.gesture(...) calls."; };
      autostart = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra hl.exec_cmd lines run on hyprland.start."; };
      browser = lib.mkOption { type = lib.types.str; default = "librewolf"; description = "Command SUPER+W launches."; };
      workspaceBinds = lib.mkOption {
        type = lib.types.lines;
        default = ''
          for i = 1, 9 do
            hl.bind(M .. " + " .. i,         hl.dsp.focus({ workspace = tostring(i) }))
            hl.bind(M .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
          end
        '';
        description = "How SUPER+1..9 behaves (plain workspaces, or per-monitor slices).";
      };
      binds = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra host-specific keybinds."; };
      popupClasses = lib.mkOption {
        type = lib.types.str;
        default = "feh|mpv|pureref|qalculate|iwgtk|desktop-portal|missioncenter";
        description = "Regex alternation of window classes that should float.";
      };
      windowRules = lib.mkOption { type = lib.types.lines; default = ""; description = "Extra hl.window_rule(...) calls."; };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = (with pkgs; [
      awww
      hypridle
      hyprlock
      hyprsunset            # night mode / colour temperature (see SUPER+SHIFT+N)
      libnotify
      wayland-pipewire-idle-inhibit
      hyprshot
      hyprpicker
      wlogout
      cliphist
      wl-clipboard
      playerctl
      brightnessctl
      udiskie
      iwgtk
      mission-center
      hyprsysteminfo
      nerd-fonts.adwaita-mono
    ]) ++ [ hyprsunsetToggle ] ++ cfg.extraPackages;

    xdg.configFile = {

      # ── Palette (consumed by hyprlock.conf via `source`) ─────────────────
      "hypr-hyprlain/assets/palette/palette.conf".text = palette-conf;
      "hypr-hyprlain/assets/palette/palette.css".text  = palette-css;

      # ── Hyprland session config — Lua (Hyprland 0.55+) ───────────────────
      # Validate changes with `Hyprland --verify-config`.
      "hypr-hyprlain/hyprland.lua".text = ''
        -- Hyprlain session — ${cfg.description}

        --------------------- PALETTE ---------------------
        local c = {
          backprimary="000000", backsecondary="1A1A1A", backtertiary="2A2A2A",
          foreprimary="CE7688", foresecondary="BA6A7B", foretertiary="A05969",
          forequaternary="965363", foresenary="804654", foreoctonary="5D333C",
          highprimary="C1B48E",
        }
        local function rgb(hex) return "rgb(" .. hex .. ")" end

        --------------------- MONITORS ---------------------
        ${cfg.lua.monitors}

        --------------------- WORKSPACES ---------------------
        ${cfg.lua.workspaceRules}

        --------------------- ENV ---------------------
        hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

        --------------------- LOOK & FEEL ---------------------
        hl.config({
          general = {
            border_size = 2,
            gaps_in  = 3,
            gaps_out = 6,
            layout = "dwindle",
            col = {
              active_border   = rgb(c.foreprimary),
              inactive_border = rgb(c.foresecondary),
            },
          },
          decoration = {
            rounding         = 0,
            rounding_power   = 2,
            active_opacity   = 1.0,
            inactive_opacity = 0.8,
            dim_inactive     = false,
            -- dim_strength stays 0 as a belt-and-suspenders: `hyprctl reload`
            -- won't flip dim_inactive back to false at runtime, so a bare
            -- reload could otherwise re-enable the grey dim. strength 0 makes
            -- the dim a no-op regardless of the boolean.
            dim_strength     = 0.0,
            dim_special      = 0.6,
            dim_around       = 0.6,
            blur = {
              enabled = true, size = 10, ignore_opacity = false,
              noise = 0.05, contrast = 0.5, brightness = 1.5,
              vibrancy = 0.1696, vibrancy_darkness = 0.0,
            },
            shadow = {
              enabled = true, range = 100, render_power = 4,
              color = rgb(c.foreoctonary), color_inactive = rgb(c.backprimary),
            },
          },
          group = {
            auto_group = false,
            focus_removed_window = false,
            drag_into_group = 2,
            merge_groups_on_drag = false,
            col = {
              border_active          = rgb(c.foreprimary),
              border_inactive        = rgb(c.forequaternary),
              border_locked_active   = rgb(c.foreprimary),
              border_locked_inactive = rgb(c.forequaternary),
            },
            groupbar = {
              font_size = 14, height = 16, indicator_height = 2, text_offset = -2,
              rounding = 0, gradient_rounding = 0, gradients = true,
              col = {
                active          = rgb(c.foreprimary),
                inactive        = rgb(c.forequaternary),
                locked_active   = rgb(c.foreprimary),
                locked_inactive = rgb(c.forequaternary),
              },
              text_color = rgb(c.backsecondary),
            },
          },
          misc = {
            disable_hyprland_logo = true,
            disable_splash_rendering = true,
            col = { splash = rgb(c.highprimary) },
            font_family = "AdwaitaMono Nerd Font",
            mouse_move_enables_dpms = true,
            key_press_enables_dpms = true,
            enable_swallow = true,
            focus_on_activate = true,
            background_color = rgb(c.backprimary),
          },
          -- 0 is the upstream default (ConfigValues.cpp: render:direct_scanout).
          -- 1 means "scan out ANY solitary window", which is a known source of
          -- artifacts; only 2 ("auto") restricts it to fullscreen game content.
          render = { direct_scanout = 0 },
          cursor = {
            persistent_warps = true,
            warp_on_change_workspace = 1,
            hide_on_key_press = true,
          },
          ecosystem = { no_update_news = true, no_donation_nag = true },
          dwindle = { preserve_split = true, precise_mouse_move = true },
          master = { allow_small_split = true, new_status = "master", new_on_top = true, orientation = "center" },
          input = {
            -- The DEFAULT layout, applied to every keyboard that has no
            -- hl.device rule of its own below. Deliberately a single layout:
            -- a second entry here would put every keyboard into a SHIFT+N
            -- cycle that can strand you on the wrong one.
            kb_layout = "${cfg.lua.kbLayout}",
            kb_variant = "${cfg.lua.kbVariant}",
            follow_mouse = 1,
            touchpad = { ${cfg.lua.touchpad} },
          },
          animations = { enabled = true },
        })

        --------------------- PER-DEVICE INPUT ---------------------
        ${cfg.lua.devices}

        --------------------- GESTURES ---------------------
        ${cfg.lua.gestures}

        --------------------- ANIMATIONS ---------------------
        hl.curve("linear",       { type = "bezier", points = { {0.00,0.00}, {1.00,1.00} } })
        hl.curve("easeOutQuint", { type = "bezier", points = { {0.23,1.00}, {0.32,1.00} } })
        hl.curve("almostLinear", { type = "bezier", points = { {0.50,0.50}, {0.75,1.00} } })
        hl.curve("quick",        { type = "bezier", points = { {0.15,0.00}, {0.10,1.00} } })
        hl.curve("overshoot",    { type = "bezier", points = { {0.05,0.90}, {0.10,1.10} } })

        hl.animation({ leaf = "windows",    enabled = true, speed = 4.79, bezier = "easeOutQuint" })
        hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4.10, bezier = "overshoot" })
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear" })
        hl.animation({ leaf = "border",     enabled = true, speed = 5.50, bezier = "easeOutQuint" })
        hl.animation({ leaf = "fade",       enabled = true, speed = 3.03, bezier = "quick" })
        hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "quick", style = "fade" })

        --------------------- AUTOSTART ---------------------
        local home = os.getenv("HOME")
        hl.on("hyprland.start", function()
          hl.exec_cmd("waybar --config " .. home .. "/.config/waybar-hyprlain/config --style " .. home .. "/.config/waybar-hyprlain/style.css")
          -- Distinctly classed so the window rule below can pin it to
          -- workspace 1. SUPER+Q still launches a plain, unclassed kitty that
          -- opens wherever you currently are.
          hl.exec_cmd("kitty --class hyprlain-term -c " .. home .. "/.config/kitty-hyprlain/kitty.conf")
          hl.exec_cmd("dunst -config " .. home .. "/.config/dunst-hyprlain/dunstrc")
          hl.exec_cmd("hypridle -c " .. home .. "/.config/hypr-hyprlain/hypridle.conf")
          -- Holds a Wayland idle inhibitor for as long as anything is playing
          -- audio through PipeWire, so hypridle never dims/locks/suspends
          -- during videos or voice calls. See hypr-hyprlain/idle-inhibit.toml.
          hl.exec_cmd("wayland-pipewire-idle-inhibit -c " .. home .. "/.config/hypr-hyprlain/idle-inhibit.toml")
          hl.exec_cmd("udiskie")
          hl.exec_cmd("nm-applet")
          hl.exec_cmd("systemctl --user start hyprpolkitagent")
          -- Vicinae is a daemon: `vicinae toggle` only shows the window if the
          -- server is already up, so start it here.
          hl.exec_cmd("vicinae server")
          -- Colour-temperature daemon for SUPER+SHIFT+N / XF86 night-mode keys.
          -- -t 6500 is "identity", so starting it changes nothing until asked.
          hl.exec_cmd("hyprsunset -t 6500")
          -- Wallpaper: Stylix's hyprpaper target is disabled (see
          -- theme-hyprlain.nix), so this session draws the Hyprlain animated
          -- GIF itself with awww (the renamed swww). The sleep lets the daemon
          -- come up before `awww img` connects to it.
          hl.exec_cmd("awww-daemon")
          hl.exec_cmd("sleep 1.5 && awww img ${wallpaperGif}")
          hl.exec_cmd("wl-paste --type text --watch cliphist store")
          hl.exec_cmd("wl-paste --type image --watch cliphist store")
          ${cfg.lua.autostart}
        end)

        --------------------- KEYBINDS ---------------------
        local M = "SUPER"
        local terminal = "kitty -c " .. home .. "/.config/kitty-hyprlain/kitty.conf"
        local browser  = "${cfg.lua.browser}"
        local files    = "dolphin"

        hl.bind(M .. " + Q", hl.dsp.exec_cmd(terminal))
        hl.bind(M .. " + W", hl.dsp.exec_cmd(browser))
        hl.bind(M .. " + E", hl.dsp.exec_cmd(files))
        hl.bind(M .. " + T", hl.dsp.exec_cmd(terminal .. " -e nvim"))
        hl.bind(M .. " + SPACE", hl.dsp.exec_cmd("vicinae toggle"))

        hl.bind(M .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -fhex"))
        hl.bind(M .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot --mode=region --freeze --output-folder=" .. home .. "/Media/Screenshots"))
        hl.bind("Print", hl.dsp.exec_cmd("hyprshot --mode=region --freeze --output-folder=" .. home .. "/Media/Screenshots"))

        -- Power / logout overlay (wlogout). Reachable three ways, all landing
        -- on the same menu: this keybind, the Waybar power button, and the
        -- physical power button (logind is told to ignore the power key in
        -- modules/desktop/power-menu.nix, and it arrives here as XF86PowerOff).
        hl.bind(M .. " + ESCAPE", hl.dsp.exec_cmd("${wlogoutCmd}"))
        hl.bind("XF86PowerOff",   hl.dsp.exec_cmd("${wlogoutCmd}"), { locked = true })

        -- pkill (procps), not killall (psmisc, which isn't installed)
        hl.bind(M .. " + O", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
        hl.bind(M .. " + X", hl.dsp.window.close())
        hl.bind(M .. " + F", hl.dsp.window.fullscreen())
        hl.bind(M .. " + V", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(M .. " + B", hl.dsp.window.pseudo())
        hl.bind(M .. " + N", hl.dsp.layout("togglesplit"))
        hl.bind(M .. " + M", hl.dsp.group.toggle())

        ${cfg.lua.workspaceBinds}

        hl.bind(M .. " + S", hl.dsp.workspace.toggle_special("magic"))
        hl.bind(M .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }))
        hl.bind(M .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))

        hl.bind(M .. " + CTRL + H", hl.dsp.group.prev())
        hl.bind(M .. " + CTRL + L", hl.dsp.group.next())
        hl.bind(M .. " + SHIFT + H", hl.dsp.group.move_window("l"))
        hl.bind(M .. " + SHIFT + L", hl.dsp.group.move_window("r"))
        hl.bind(M .. " + SHIFT + K", hl.dsp.group.move_window("u"))
        hl.bind(M .. " + SHIFT + J", hl.dsp.group.move_window("d"))

        hl.bind(M .. " + H", hl.dsp.focus({ direction = "left" }))
        hl.bind(M .. " + J", hl.dsp.focus({ direction = "down" }))
        hl.bind(M .. " + K", hl.dsp.focus({ direction = "up" }))
        hl.bind(M .. " + L", hl.dsp.focus({ direction = "right" }))

        hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
        hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        --------------------- MEDIA / LAPTOP FUNCTION KEYS ---------------------
        hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
        hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
        hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
        hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })
        hl.bind("XF86KbdBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -d '*kbd_backlight' s 10%+"), { locked = true, repeating = true })
        hl.bind("XF86KbdBrightnessDown",hl.dsp.exec_cmd("brightnessctl -d '*kbd_backlight' s 10%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
        hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
        -- HP's "display switch" key (Fn+F4 on an EliteBook) — mirror/extend is
        -- a compositor decision, so just re-apply the configured monitor
        -- layout, which is what you want after (un)plugging an external panel.
        hl.bind("XF86Display", hl.dsp.exec_cmd("hyprctl reload"), { locked = true })

        -- Night mode (blue-light filter). SUPER+SHIFT+N toggles, and the
        -- XF86 keys some keyboards emit for it are wired to the same thing.
        hl.bind(M .. " + SHIFT + N", hl.dsp.exec_cmd("hyprsunset-toggle"))
        hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"), { locked = true })

        -- SUPER equivalents for 65%/compact keyboards without dedicated media
        -- keys (also reachable by clicking/scrolling the Waybar modules).
        hl.bind(M .. " + equal", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
        hl.bind(M .. " + minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
        hl.bind(M .. " + backslash", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
        hl.bind(M .. " + P",      hl.dsp.exec_cmd("playerctl play-pause"))
        hl.bind(M .. " + period", hl.dsp.exec_cmd("playerctl next"))
        hl.bind(M .. " + comma",  hl.dsp.exec_cmd("playerctl previous"))
        hl.bind(M .. " + bracketright", hl.dsp.exec_cmd("brightnessctl s 10%+"))
        hl.bind(M .. " + bracketleft",  hl.dsp.exec_cmd("brightnessctl s 10%-"))

        ${cfg.lua.binds}

        --------------------- WINDOW RULES ---------------------
        hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
        hl.window_rule({
          name = "fix-xwayland-drags",
          match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
          no_focus = true,
        })
        local popups = "${cfg.lua.popupClasses}"
        hl.window_rule({ name = "popup-class", match = { class = "(?i).*(" .. popups .. ").*" }, float = true, focus_on_activate = true })
        hl.window_rule({ name = "popup-pip",   match = { title = "(?i).*(Picture-in-Picture).*" }, float = true, focus_on_activate = true })
        hl.window_rule({ name = "forced",      match = { class = "(?i).*(hyprpolkitagent).*" }, stay_focused = true, dim_around = true })

        hl.window_rule({
          name  = "startup-term",
          match = { class = "^(hyprlain-term)$" },
          workspace = "1",
        })

        ${cfg.lua.windowRules}
      '';

      # ── Kitty (Hyprlain-scoped: launched via `kitty -c` in the session) ────
      "kitty-hyprlain/kitty.conf".text = ''
        font_family      AdwaitaMono Nerd Font
        font_size        ${cfg.kitty.fontSize}
        cursor_beam_thickness 2.0
        cursor_trail     1
        tab_bar_align    center
        confirm_os_window_close 0

        ${cfg.kitty.extraSettings}

        ${kittyColors}
      '';

      # ── Dunst (Hyprlain-scoped: launched via `dunst -config`) ─────────────
      "dunst-hyprlain/dunstrc".text = ''
        [global]
            monitor = 0
            follow = mouse
            width = (200, 400)
            height = (0, 600)
            origin = top-right
            offset = (10, 50)
            scale = 0
            notification_limit = 20
            progress_bar = true
            progress_bar_height = 10
            progress_bar_frame_width = 1
            progress_bar_min_width = 150
            progress_bar_max_width = 300
            progress_bar_corner_radius = 0
            indicate_hidden = yes
            transparency = 0
            separator_height = 2
            padding = 0
            horizontal_padding = 0
            text_icon_padding = 2
            frame_width = 2
            frame_color = "#CE7688"
            gap_size = 0
            separator_color = "#CE7688"
            sort = urgency_descending
            font = AdwaitaMono Nerd Font 12
            line_height = 0
            markup = full
            format = "<b>%s</b>\n%b"
            alignment = center
            vertical_alignment = center
            show_age_threshold = 60
            ellipsize = middle
            ignore_newline = no
            stack_duplicates = true
            hide_duplicate_count = false
            show_indicators = yes
            enable_recursive_icon_lookup = true
            icon_theme = Adwaita
            icon_position = left
            min_icon_size = 32
            max_icon_size = 128
            sticky_history = yes
            history_length = 20
            corner_radius = 0
            force_xwayland = false
            mouse_left_click = close_current
            mouse_middle_click = do_action, close_current
            mouse_right_click = close_all

        [urgency_low]
            background = "#000000"
            foreground = "#C1B48E"
            timeout = 10

        [urgency_normal]
            background = "#000000"
            foreground = "#C1B48E"
            timeout = 10
            override_pause_level = 30
            default_icon = dialog-information

        [urgency_critical]
            background = "#965363"
            foreground = "#C1B48E"
            timeout = 0
            override_pause_level = 60
            default_icon = dialog-warning
      '';

      # ── Hypridle ──────────────────────────────────────────────────────────
      "hypr-hyprlain/hypridle.conf".text = ''
        general {
          lock_cmd         = pidof hyprlock || hyprlock -c ~/.config/hypr-hyprlain/hyprlock.conf
          before_sleep_cmd = loginctl lock-session
          # Both halves matter on resume: the panel has to be switched back on
          # AND the backlight restored, because the dim listener below may have
          # driven it to ~1% before the machine went under. Opening the lid
          # generates no input event, so nothing else would run these.
          after_sleep_cmd  = ${dpmsOn} ; brightnessctl -r
        }

        listener {
          timeout    = ${toString cfg.idle.dimTimeout}
          on-timeout = brightnessctl -s set 10
          on-resume  = brightnessctl -r
        }

        listener {
          timeout    = ${toString cfg.idle.lockTimeout}
          on-timeout = loginctl lock-session
        }

        listener {
          timeout    = ${toString cfg.idle.dpmsTimeout}
          on-timeout = ${dpmsOff}
          on-resume  = ${dpmsOn} ; brightnessctl -r
        }

        listener {
          timeout    = ${toString cfg.idle.suspendTimeout}
          on-timeout = systemctl suspend
        }
      '';

      # ── Idle inhibit while audio is playing ───────────────────────────────
      # hypridle only counts input events as activity, so watching a video or
      # sitting in a voice call without touching the mouse would still dim,
      # lock and eventually suspend. wayland-pipewire-idle-inhibit watches the
      # PipeWire graph and raises a Wayland idle inhibitor whenever a playback
      # stream is running, which hypridle honours.
      "hypr-hyprlain/idle-inhibit.toml".text = ''
        verbosity = "WARN"

        # Ignore blips shorter than this (notification chimes, UI sounds).
        media_minimum_duration = 10

        idle_inhibitor = "wayland"

        ${cfg.idle.blacklist}
      '';

      # ── Hyprlock ──────────────────────────────────────────────────────────
      "hypr-hyprlain/hyprlock.conf".text = ''
        source = ~/.config/hypr-hyprlain/assets/palette/palette.conf
        $font            = AdwaitaMono Nerd Font
        $background_path = ${lockWall}

        general {
          ignore_empty_input = true
        }

        animations {
          bezier = linear, 1, 1, 0, 0

          animation = fadeIn,         1, 2.5, linear
          animation = fadeOut,        1, 2.5, linear
          animation = inputFieldDots, 1, 1,   linear
        }

        background {
          path        = $background_path
          color       = rgb($backprimary)
          blur_passes = 2
          blur_size   = 10
        }

        input-field {
          size              = 25%, 5%
          outline_thickness = 2
          inner_color       = rgb($backprimary)
          outer_color       = rgb($foreprimary)
          check_color       = rgb($forequaternary)
          fail_color        = rgb($highprimary)
          font_color        = rgb($highprimary)
          fade_on_empty     = true
          fade_timeout      = 5000
          rounding          = 0
          font_family       = $font
          placeholder_text  = $USER
          fail_text         = $PAMFAIL
          dots_text_format  = *
          dots_rounding     = -1
          dots_size         = 0.4
          dots_spacing      = 0.6
          halign            = center
          valign            = center
        }

        label {
          monitor     =
          text        = <b>$TIME</b>
          color       = rgb($highprimary)
          font_size   = 64
          font_family = $font
          position    = 0, -7%
          halign      = center
          valign      = top
        }

        label {
          monitor     =
          text        = cmd[update:60000] date +"%A, %d %B"
          color       = rgb($highprimary)
          font_size   = 16
          font_family = $font
          position    = 0, -15%
          halign      = center
          valign      = top
        }

        label {
          monitor   =
          text      = $LAYOUT
          color     = rgb($highprimary)
          font_size = 16
          onclick   = hyprctl switchxkblayout all next
          position  = -0.25%, 0.25%
          halign    = right
          valign    = bottom
        }
      '';

      # ── Waybar config ─────────────────────────────────────────────────────
      # The icons here are literal Nerd-Font glyphs (UTF-8), which JSON accepts
      # directly. They are FRAGILE: an editor or formatter that mangles
      # private-use codepoints silently turns them into empty strings, which is
      # how the cpu/mem/workspace icons went blank once already. If icons
      # disappear, check the bytes before checking waybar. JSON \uXXXX escapes
      # are the safe alternative if that keeps happening.
      "waybar-hyprlain/config".text = ''
        {
          "layer": "top",
          "position": "top",
          "height": 24,
          "spacing": 0,
        ${lib.optionalString (cfg.waybar.outputs != null) "  \"output\": ${jsonList cfg.waybar.outputs},"}
          "margin-left": ${toString cfg.waybar.margin},
          "margin-right": ${toString cfg.waybar.margin},
          "modules-left": [
            "hyprland/workspaces"
          ],
          "modules-center": [
            "hyprland/window"
          ],
          "modules-right": ${jsonList cfg.waybar.modulesRight},
          "group/hiddentray": {
            "orientation": "horizontal",
            "modules": [
              "custom/expand",
              "cpu",
              "temperature",
              "memory",
              "tray"
            ],
            "drawer": {
              "transition-duration": 250,
              "transition-left-to-right": false,
              "click-to-reveal": true
            }
          },
          "hyprland/workspaces": {
            "active-only": false,
            "all-outputs": false,
            "disable-scroll": true,
            "warp-on-scroll": false,
            "format": "{icon}",
            "format-icons": {
              ${cfg.waybar.workspaceIcons}
            }
          },
          "temperature": {
            ${cfg.waybar.temperature}
          },
        ${cfg.waybar.extraModules}
        ${waybarCommonModules}
        }
      '';

      # ── Waybar style ──────────────────────────────────────────────────────
      "waybar-hyprlain/style.css".text = ''
        ${palette-css}

        * {
          font-family: "AdwaitaMono Nerd Font";
          font-size: 16px;
          font-weight: bold;
          color: @highprimary;
        }

        window#waybar {
          background-color: @backprimary;
          border: solid @foreprimary;
          border-width: 0px 2px 2px 2px;
          transition-property: background-color;
          transition-duration: 0.5s;
        }

        button,
        button:hover,
        #workspaces #workspaces button,
        #workspaces button:hover {
          color: @highprimary;
          padding: 0px 2px 0px 2px;
          margin: 0px;
          border: none;
          background: inherit;
          background-color: transparent;
          box-shadow: inset 0px 0px 0px 0px @foreprimary;
        }

        tooltip,
        tooltip *,
        #tray menu {
          color: @highprimary;
          background-color: @backprimary;
          text-shadow: none;
        }

        #mode, #battery, #cpu, #memory, #disk, #backlight, #network,
        #wireplumber, #custom-media, #tray, #idle_inhibitor, #scratchpad,
        #power-profiles-daemon, #mpd {
          padding: 0px 6px 0px 0px;
        }

        #temperature { padding: 0px 3px 0px 3px; }
        #image       { padding: 0px 4px 2px 0px; }
        #pulseaudio  { padding: 0px 10px 0px 0px; }
        #mpris       { padding: 0px 10px 0px 0px; }

        /* The power button had no padding *and* its Nerd-Font glyph rendered as
           a near-zero-width sliver on one monitor and an invisible-but-clickable
           box on the other. Use a plain Unicode power symbol with an explicit
           min-width so it's always a visible, easy-to-hit target. */
        #custom-power {
          color: @foreprimary;
          min-width: 22px;
          padding: 0px 14px 0px 10px;
        }
        #clock       { padding: 0px 3px 0px 0px; }

        /* The "eye" drawer toggle (custom/expand) uses the characteristic Lain
           eye image as its icon (not a font glyph), painted as a background so
           it reveals the cpu/temp/memory/tray drawer next to the power button.
           (GTK CSS shows the GIF's first frame — a static Lain eye.) */
        #custom-expand {
          background-image: url("${eyeIcon}");
          background-repeat: no-repeat;
          background-position: center;
          background-size: 18px 18px;
          min-width: 20px;
          padding: 0px 6px 0px 6px;
        }

        #tray > .needs-attention,
        #pulseaudio.muted,
        #temperature.critical,
        #battery.critical,
        #privacy-item.screenshare,
        #privacy-item.audio-out {
          -gtk-icon-effect: highlight;
          background-color: @foresecondary;
        }

        ${cfg.waybar.extraStyle}
      '';

      # ── Wlogout style with the Hyprlain GIF icons ─────────────────────────
      "hypr-hyprlain/wlogout.css".text = ''
        ${palette-css}

        * {
          all: unset;
          font-family: "AdwaitaMono Nerd Font";
          font-size: 16px;
          font-weight: bold;
        }

        window { background-color: @backprimary; }

        button {
          color: @highprimary;
          background-color: @backprimary;
          background-repeat: no-repeat;
          background-position: center;
          background-size: 50%;
        }

        button:focus,
        button:active,
        button:hover {
          background-color: @backsecondary;
          border: 2px solid @foreprimary;
        }

        #lock     { background-image: url("${iconLock}"); }
        #logout   { background-image: url("${iconLogout}"); }
        #suspend  { background-image: url("${iconSuspend}"); }
        #hibernate { background-image: url("${iconHibern}"); }
        #shutdown { background-image: url("${iconShutdown}"); }
        #reboot   { background-image: url("${iconReboot}"); }
      '';

      # ── Wlogout layout ────────────────────────────────────────────────────
      # The default layout's logout action is `loginctl terminate-user $USER`,
      # which under a uwsm-managed session tears the user manager down hard and
      # leaves the VT at a blinking cursor instead of returning to SDDM. `uwsm
      # stop` stops the compositor's systemd scope gracefully, so SDDM reclaims
      # the VT.
      "hypr-hyprlain/wlogout-layout".text = ''
        {
            "label" : "lock",
            "action" : "loginctl lock-session",
            "text" : "Lock",
            "keybind" : "l"
        }
        {
            "label" : "logout",
            "action" : "uwsm stop",
            "text" : "Logout",
            "keybind" : "e"
        }
        {
            "label" : "suspend",
            "action" : "systemctl suspend",
            "text" : "Suspend",
            "keybind" : "u"
        }
        {
            "label" : "hibernate",
            "action" : "systemctl hibernate",
            "text" : "Hibernate",
            "keybind" : "h"
        }
        {
            "label" : "shutdown",
            "action" : "systemctl poweroff",
            "text" : "Shutdown",
            "keybind" : "s"
        }
        {
            "label" : "reboot",
            "action" : "systemctl reboot",
            "text" : "Reboot",
            "keybind" : "r"
        }
      '';
    };
  };
}
