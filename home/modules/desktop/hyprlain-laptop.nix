{ config, pkgs, lib, inputs, ... }:

# Single-monitor adaptation of turing's home/modules/desktop/hyprlain.nix for
# the EliteBook 840 G2's built-in panel (eDP-1). turing's version is wired to
# a specific three-monitor desk (named outputs, an ambient CRT with an
# auto-switching btop/cava dashboard, per-monitor workspace slicing) — none of
# that applies to one laptop screen, so this drops it entirely rather than
# carrying dead logic. Everything else (palette, kitty/dunst/hypridle/hyprlock/
# waybar/wlogout look) is kept as close to turing's as a single output allows,
# so both machines still read as the same "Hyprlain" session.

let
  hl = inputs.hyprlain-src;
  assets = "${hl}/src/hyprland/src/assets";

  # Kitty theme colours (from upstream src/hyprland/src/kitty/current-theme.conf)
  kittyColors = ''
    foreground            #C1B48E
    background            #000000
    selection_foreground  #C1B48E
    selection_background  #804654
    url_color             #968C6E
    cursor                #804654
    cursor_text_color     #C1B48E

    color0  #1A1A1A
    color8  #2A2A2A
    color1  #CE7688
    color9  #CE7688
    color2  #BA6A7B
    color10 #BA6A7B
    color3  #A05969
    color11 #A05969
    color4  #965363
    color12 #965363
    color5  #8E4E5D
    color13 #8E4E5D
    color6  #804654
    color14 #804654
    color7  #6F3D49
    color15 #6F3D49
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

  palette-conf = ''
    $backprimary   = 000000
    $backsecondary = 1A1A1A
    $foreprimary   = CE7688
    $forequaternary = 965363
    $highprimary   = C1B48E
  '';

  wallpaperGif = "${assets}/media/anim/bg_dark_anim_0_08.gif";
  lockWall     = "${assets}/media/imgs/lain_wall.png";

  iconLock     = "${assets}/media/anim/icons/laintrain.gif";
  iconLogout   = "${assets}/media/anim/icons/VisLain.gif";
  iconSuspend  = "${assets}/media/anim/icons/SunD.gif";
  iconHibern   = "${assets}/media/anim/icons/cxc4.gif";
  iconShutdown = "${assets}/media/anim/icons/acid.gif";
  iconReboot   = "${assets}/media/anim/icons/aether-preview-02.gif";
in
{
  home.packages = with pkgs; [
    awww
    hypridle
    hyprlock
    wayland-pipewire-idle-inhibit
    hyprshot
    hyprpicker
    wlogout
    cliphist
    wl-clipboard
    playerctl
    udiskie
    iwgtk
    mission-center
    hyprsysteminfo
    nerd-fonts.adwaita-mono
  ];

  xdg.configFile = {
    "hypr-hyprlain/assets/palette/palette.conf".text = palette-conf;

    "hypr-hyprlain/hyprland.lua".text = ''
      -- Hyprlain session (cerf) — single-output laptop panel, Hyprland 0.55 Lua.

      --------------------- PALETTE ---------------------
      local c = {
        backprimary="000000", backsecondary="1A1A1A", backtertiary="2A2A2A",
        foreprimary="CE7688", foresecondary="BA6A7B", foretertiary="A05969",
        forequaternary="965363", foresenary="804654", foreoctonary="5D333C",
        highprimary="C1B48E",
      }
      local function rgb(hex) return "rgb(" .. hex .. ")" end

      --------------------- MONITOR ---------------------
      -- Just the built-in panel. Wildcard rule picks whatever's connected —
      -- fine for a laptop with a single fixed eDP output; an external
      -- monitor plugged in later gets the same "preferred/auto" treatment
      -- rather than being ignored.
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

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
          kb_layout = "us",
          kb_variant = "altgr-intl",
          follow_mouse = 1,
          touchpad = { disable_while_typing = false, middle_button_emulation = true, tap_to_click = true, natural_scroll = true },
        },
        gestures = {
          workspace_swipe = true,
        },
        animations = { enabled = true },
      })

      --------------------- ANIMATIONS ---------------------
      hl.curve("linear",       { type = "bezier", points = { {0.00,0.00}, {1.00,1.00} } })
      hl.curve("easeOutQuint", { type = "bezier", points = { {0.23,1.00}, {0.32,1.00} } })
      hl.curve("overshoot",    { type = "bezier", points = { {0.05,0.90}, {0.10,1.10} } })
      hl.curve("quick",        { type = "bezier", points = { {0.15,0.00}, {0.10,1.00} } })

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
        hl.exec_cmd("kitty --class hyprlain-term -c " .. home .. "/.config/kitty-hyprlain/kitty.conf")
        hl.exec_cmd("dunst -config " .. home .. "/.config/dunst-hyprlain/dunstrc")
        hl.exec_cmd("hypridle -c " .. home .. "/.config/hypr-hyprlain/hypridle.conf")
        hl.exec_cmd("wayland-pipewire-idle-inhibit -c " .. home .. "/.config/hypr-hyprlain/idle-inhibit.toml")
        hl.exec_cmd("udiskie")
        hl.exec_cmd("nm-applet")
        hl.exec_cmd("systemctl --user start hyprpolkitagent")
        hl.exec_cmd("vicinae server")
        hl.exec_cmd("awww-daemon")
        hl.exec_cmd("sleep 1.5 && awww img ${wallpaperGif}")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
      end)

      --------------------- KEYBINDS ---------------------
      local M = "SUPER"
      local terminal = "kitty -c " .. home .. "/.config/kitty-hyprlain/kitty.conf"
      local browser  = "librewolf"
      local files    = "dolphin"

      hl.bind(M .. " + Q", hl.dsp.exec_cmd(terminal))
      hl.bind(M .. " + W", hl.dsp.exec_cmd(browser))
      hl.bind(M .. " + E", hl.dsp.exec_cmd(files))
      hl.bind(M .. " + T", hl.dsp.exec_cmd(terminal .. " -e nvim"))
      hl.bind(M .. " + SPACE", hl.dsp.exec_cmd("vicinae toggle"))

      hl.bind(M .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -fhex"))
      hl.bind(M .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot --mode=region --freeze --output-folder=" .. home .. "/Pictures/Screenshots"))
      hl.bind("Print", hl.dsp.exec_cmd("hyprshot --mode=region --freeze --output-folder=" .. home .. "/Pictures/Screenshots"))
      hl.bind(M .. " + ESCAPE", hl.dsp.exec_cmd("wlogout -l " .. home .. "/.config/hypr-hyprlain/wlogout-layout -C " .. home .. "/.config/hypr-hyprlain/wlogout.css"))

      hl.bind(M .. " + O", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
      hl.bind(M .. " + X", hl.dsp.window.close())
      hl.bind(M .. " + F", hl.dsp.window.fullscreen())
      hl.bind(M .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(M .. " + B", hl.dsp.window.pseudo())
      hl.bind(M .. " + N", hl.dsp.layout("togglesplit"))
      hl.bind(M .. " + M", hl.dsp.group.toggle())

      -- Single monitor, so SUPER+N is just the plain global workspace switch
      -- (no per-monitor slicing needed — that machinery existed on turing
      -- purely to make SUPER+N deterministic across three screens).
      for i = 1, 9 do
        hl.bind(M .. " + " .. i,         hl.dsp.focus({ workspace = tostring(i) }))
        hl.bind(M .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
      end

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

      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
      hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

      hl.bind(M .. " + equal", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"))
      hl.bind(M .. " + minus", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
      hl.bind(M .. " + backslash", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
      hl.bind(M .. " + P",      hl.dsp.exec_cmd("playerctl play-pause"))
      hl.bind(M .. " + period", hl.dsp.exec_cmd("playerctl next"))
      hl.bind(M .. " + comma",  hl.dsp.exec_cmd("playerctl previous"))

      --------------------- WINDOW RULES ---------------------
      hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
      hl.window_rule({
        name = "fix-xwayland-drags",
        match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
        no_focus = true,
      })
      local popups = "feh|mpv|pureref|qalculate|iwgtk|desktop-portal|missioncenter|wireshark|gns3"
      hl.window_rule({ name = "popup-class", match = { class = "(?i).*(" .. popups .. ").*" }, float = true, focus_on_activate = true })
      hl.window_rule({ name = "popup-pip",   match = { title = "(?i).*(Picture-in-Picture).*" }, float = true, focus_on_activate = true })
      hl.window_rule({ name = "forced",      match = { class = "(?i).*(hyprpolkitagent).*" }, stay_focused = true, dim_around = true })

      hl.window_rule({
        name  = "startup-term",
        match = { class = "^(hyprlain-term)$" },
        workspace = "1",
      })
    '';

    # ── Kitty (Hyprlain-scoped: launched via `kitty -c` in the session) ──────
    "kitty-hyprlain/kitty.conf".text = ''
      font_family      AdwaitaMono Nerd Font
      font_size        13.0
      cursor_beam_thickness 2.0
      cursor_trail     1
      tab_bar_align    center
      confirm_os_window_close 0

      ${kittyColors}
    '';

    # ── Dunst ─────────────────────────────────────────────────────────────
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

    # ── Hypridle ─────────────────────────────────────────────────────────────
    "hypr-hyprlain/hypridle.conf".text = ''
      general {
        lock_cmd         = pidof hyprlock || hyprlock -c ~/.config/hypr-hyprlain/hyprlock.conf
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd  = hyprctl dispatch dpms on
      }

      listener {
        timeout    = 150
        on-timeout = brightnessctl -s set 10
        on-resume  = brightnessctl -r
      }

      listener {
        timeout    = 300
        on-timeout = loginctl lock-session
      }

      listener {
        timeout    = 330
        on-timeout = hyprctl dispatch dpms off
        on-resume  = hyprctl dispatch dpms on && brightnessctl -r
      }

      # Laptop-specific: suspend on idle sooner than turing's desktop (30min)
      # so battery isn't drained overnight if it's left unplugged.
      listener {
        timeout    = 900
        on-timeout = systemctl suspend
      }
    '';

    "hypr-hyprlain/idle-inhibit.toml".text = ''
      verbosity = "WARN"
      media_minimum_duration = 10
      idle_inhibitor = "wayland"
    '';

    # ── Hyprlock ─────────────────────────────────────────────────────────────
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
        text      = $LAYOUT[en,it]
        color     = rgb($highprimary)
        font_size = 16
        onclick   = hyprctl switchxkblayout all next
        position  = -0.25%, 0.25%
        halign    = right
        valign    = bottom
      }
    '';

    # ── Waybar config (single output — no per-monitor "output" restriction) ──
    "waybar-hyprlain/config".text = ''
      {
        "layer": "top",
        "position": "top",
        "height": 24,
        "spacing": 0,
        "margin-left": 20,
        "margin-right": 20,
        "modules-left": [
          "hyprland/workspaces"
        ],
        "modules-center": [
          "hyprland/window"
        ],
        "modules-right": [
          "mpris",
          "pulseaudio",
          "network",
          "battery",
          "clock",
          "group/hiddentray",
          "custom/power"
        ],
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
            "1": "",  "2": "",  "3": "",
            "4": "󰲦", "5": "󰲨", "6": "󰲪",
            "7": "󰲬", "8": "󰲮", "9": "",
            "urgent": "",
            "focused": "",
            "default": ""
          }
        },
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
            "headset": "󰋎",
            "portable": ""
          },
          "scroll-step": 1,
          "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
          "max-volume": 150,
          "tooltip-format": "{icon} {volume}% — scroll to change, click to mute"
        },
        "mpris": {
          "format": "{player_icon} {title}",
          "format-paused": "{status_icon} {title}",
          "player-icons": { "default": "" },
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
        "battery": {
          "states": { "warning": 30, "critical": 15 },
          "format": "{icon} {capacity}%",
          "format-charging": " {capacity}%",
          "format-icons": ["", "", "", "", ""],
          "tooltip-format": "{time} remaining"
        },
        "clock": {
          "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
          "format-alt": "{:%Y-%m-%d}"
        },
        "temperature": {
          "critical-threshold": 80,
          "format": "{icon}",
          "format-critical": "{temperatureC}°C {icon}",
          "format-icons": ["", "", "", ""],
          "on-click-right": "missioncenter"
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
          "on-click": "wlogout -l ~/.config/hypr-hyprlain/wlogout-layout -C ~/.config/hypr-hyprlain/wlogout.css"
        }
      }
    '';

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
      #pulseaudio  { padding: 0px 10px 0px 0px; }
      #mpris       { padding: 0px 10px 0px 0px; }

      #custom-power {
        color: @foreprimary;
        min-width: 22px;
        padding: 0px 14px 0px 10px;
      }
      #clock       { padding: 0px 3px 0px 0px; }

      #custom-expand {
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
    '';

    # ── Wlogout ──────────────────────────────────────────────────────────────
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
}
