{ config, pkgs, lib, inputs, ... }:

let
  # Assets from the local Hyprlain clone, hashed into flake.lock.
  hl = inputs.hyprlain-src;
  assets = "${hl}/src/hyprland/src/assets";

  # ── Output names ─────────────────────────────────────────────────────────
  # Pinned by connector name, NOT by left-to-right x-index. The old code
  # derived a monitor's workspace slice from `sort_by(.x) | to_entries` at
  # runtime, while the workspace_rules below pinned slices by NAME. Those two
  # agreed only as long as there were exactly two outputs in the expected
  # order. Plugging in the LG (DP-1, which lands at x=0, left of everything)
  # renumbered every index: DP-1 became 0 (→ ws 1-9, already pinned to
  # HDMI-A-1), HDMI-A-1 became 1 (→ ws 10-18, pinned to DP-3), and DP-3 became
  # 2 (→ ws 19-27, pinned to nothing and not persistent). That is exactly the
  # reported breakage: SUPER+N jumping to the wrong monitor, and workspaces
  # 19-27 being unreachable/vanishing. Name-keying removes the coupling to
  # physical order entirely.
  monMain = "HDMI-A-1"; # Samsung S19D300 LCD, centre — the main display
  monRight = "DP-3"; # Samsung SyncMaster CRT, right
  monAmbient = "DP-1"; # LG T730SH CRT, ambient/bed display (see below)

  # Workspace slices. Only the two desk monitors take part in the SUPER+N
  # rotation; the ambient LG is deliberately excluded (it gets 19/20 instead,
  # reachable only by its own dedicated binds).
  wsBases = { ${monMain} = 0; ${monRight} = 9; };
  wsAmbientDash = 19; # btop / cava auto-switching dashboard
  wsAmbientMedia = 20; # movies etc., thrown here on demand

  # Shared `case` that maps the focused output to its slice base. Emitted into
  # both scripts so they can never disagree. An output that owns no slice
  # (the ambient LG, or anything hotplugged later) exits 0 without acting,
  # rather than silently falling back to base 0 and hijacking the main
  # monitor's workspaces.
  sliceCase = ''
    ACTIVE_MON=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.monitor')
    case "$ACTIVE_MON" in
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (out: base: "  ${out}) BASE=${toString base} ;;") wsBases)}
      *) exit 0 ;;
    esac
  '';

  # NOTE: this Hyprland runs a Lua config, so `hyprctl dispatch <x>` evaluates
  # its argument as LUA (it becomes `return hl.dispatch(<x>)`), NOT as a native
  # dispatcher. So we must pass a Lua expression: hl.dsp.focus({workspace=N}) to
  # switch, hl.dsp.window.move({workspace=N}) to move the window. (The native
  # `workspace N` / `movetoworkspace N` form errors out.)
  focusWsHl = pkgs.writeShellScript "hyprlain-focus-ws" ''
    N=$1
    ${sliceCase}
    hyprctl dispatch "hl.dsp.focus({workspace=$((BASE + N))})"
  '';
  moveWsHl = pkgs.writeShellScript "hyprlain-move-ws" ''
    N=$1
    ${sliceCase}
    hyprctl dispatch "hl.dsp.window.move({workspace=$((BASE + N))})"
  '';

  # ── Ambient display (LG T730SH on DP-1) ──────────────────────────────────
  # This monitor is only visible from the bed, so it is deliberately detached
  # from the desk arrangement (see the hl.monitor call in hyprland.lua): its
  # box shares no edge with the other two, which is what stops the pointer
  # from wandering onto a screen the user can't see. Everything that puts
  # focus there is therefore an explicit, deliberate keybind.

  # True when something is actually playing. Counts only PipeWire playback
  # streams in the `running` state, and excludes CamillaDSP — the always-on
  # filter chain from audio-eq.nix appears in the graph as a permanently
  # running Stream/Output/Audio node (`eq-*-out`), so counting it would mean
  # "audio is playing" forever and cava would never yield back to btop. This
  # mirrors the node_blacklist in hypr-hyprlain/idle-inhibit.toml.
  audioActive = pkgs.writeShellScript "hyprlain-audio-active" ''
    n=$(${pkgs.pipewire}/bin/pw-dump 2>/dev/null | ${pkgs.jq}/bin/jq '
      [ .[]
        | select(.type == "PipeWire:Interface:Node")
        | select(.info.props["media.class"] == "Stream/Output/Audio")
        | select(.info.state == "running")
        | select((.info.props["application.name"] // "") | test("camilladsp"; "i") | not)
        | select((.info.props["node.name"]        // "") | test("camilladsp|^eq-"; "i") | not)
      ] | length')
    [ "''${n:-0}" -gt 0 ]
  '';

  # Supervisor that owns the ambient dashboard's single terminal. btop and
  # cava are TUIs, so rather than juggling two windows and swapping which is
  # visible, one kitty runs this loop and the loop swaps which child owns the
  # tty. Switching is therefore instant and leaves no stray windows behind.
  ambientDash = pkgs.writeShellScript "hyprlain-ambient-dash" ''
    want="" current="" pid=""

    cleanup() { [ -n "$pid" ] && kill "$pid" 2>/dev/null; exit 0; }
    trap cleanup INT TERM EXIT

    while :; do
      if ${audioActive}; then want=cava; else want=btop; fi

      if [ "$want" != "$current" ]; then
        if [ -n "$pid" ]; then
          kill "$pid" 2>/dev/null
          wait "$pid" 2>/dev/null
        fi
        clear
        # `< /dev/tty` is load-bearing. POSIX says a background job in a
        # NON-INTERACTIVE shell gets its stdin redirected to /dev/null, so
        # both TUIs lost the terminal the moment they were backgrounded, and
        # btop bailed out with "No tty detected! Btop needs an interactive
        # shell". Reattaching stdin to the controlling terminal restores
        # isatty(0). Reading is safe here despite them being background jobs:
        # job control is off in a script, so they stay in this shell's process
        # group — which is the terminal's foreground group — and never take
        # SIGTTIN.
        case "$want" in
          cava) ${pkgs.cava}/bin/cava -p "$HOME/.config/cava-hyprlain/config" < /dev/tty & ;;
          btop) ${pkgs.btop}/bin/btop < /dev/tty & ;;
        esac
        pid=$!
        current="$want"
      fi

      # 2s poll: fast enough that cava comes up while the track is still
      # playing, slow enough that pw-dump costs nothing measurable.
      sleep 2
    done
  '';

  # Jump focus to the ambient monitor and back. Remembers which desk monitor
  # you came from, so the return trip lands where you left rather than always
  # snapping to the main display.
  ambientToggle = pkgs.writeShellScript "hyprlain-ambient-toggle" ''
    STATE="''${XDG_RUNTIME_DIR:-/tmp}/hyprlain-ambient-return"
    CUR=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.monitor')

    if [ "$CUR" = "${monAmbient}" ]; then
      BACK=$(cat "$STATE" 2>/dev/null)
      case "$BACK" in ${monMain}|${monRight}) ;; *) BACK="${monMain}" ;; esac
      hyprctl dispatch "hl.dsp.focus({monitor='$BACK'})"
    else
      printf '%s' "$CUR" > "$STATE"
      hyprctl dispatch "hl.dsp.focus({monitor='${monAmbient}'})"
    fi
  '';

  # At session start Hyprland focuses the first monitor it enumerated, which is
  # DP-1 (the ambient LG) — so the autostarted terminal opened on the one
  # screen that isn't visible from the desk. Park focus on the main display
  # once the outputs have settled. The startup terminal is additionally pinned
  # to workspace 1 by a window rule, so this is belt-and-braces: the rule
  # places the window, this puts the cursor and keyboard focus where they
  # belong for everything launched afterwards.
  sessionFocusMain = pkgs.writeShellScript "hyprlain-session-focus-main" ''
    sleep 2
    hyprctl dispatch "hl.dsp.focus({monitor='${monMain}'})"
    exit 0
  '';

  # Flip the ambient monitor between its dashboard and its media workspace
  # without stealing focus from the desk. Focus has to travel there briefly
  # because workspace switching is always relative to the focused monitor, so
  # the original monitor is restored immediately afterwards.
  ambientFlip = pkgs.writeShellScript "hyprlain-ambient-flip" ''
    CUR=$(hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.monitor')
    AMBWS=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r \
      '.[] | select(.name == "${monAmbient}") | .activeWorkspace.id')

    if [ "$AMBWS" = "${toString wsAmbientDash}" ]; then
      TARGET=${toString wsAmbientMedia}
    else
      TARGET=${toString wsAmbientDash}
    fi

    hyprctl dispatch "hl.dsp.focus({monitor='${monAmbient}'})"
    hyprctl dispatch "hl.dsp.focus({workspace=$TARGET})"
    [ "$CUR" != "${monAmbient}" ] && hyprctl dispatch "hl.dsp.focus({monitor='$CUR'})"
    exit 0
  '';

  # ── Display state snapshot ───────────────────────────────────────────────
  # The display fault this exists for is INTERMITTENT: across reboots the same
  # config produces different results, and it has affected the main LCD as well
  # as the CRT, so it cannot be attributed from a single broken session. Every
  # measurement taken while broken came back clean (correct modesets, correct
  # CRTC/plane geometry, pixel-perfect grim captures, unchanged EDID hashes,
  # no wlr-output-management overrides) which means the discriminating evidence
  # has to come from comparing a GOOD boot against a BAD one.
  #
  # So: after each boot, note whether the displays look right, run this, and
  # diff a good snapshot against a bad one. Output goes under ~/.local/share,
  # which is in the impermanence list (modules/core/users.nix), so snapshots
  # survive the root wipe. Runs once automatically per session and can be run
  # by hand at any time.
  displaySnapshot = pkgs.writeShellScriptBin "display-snapshot" ''
    set -u
    TAG="''${1:-auto}"
    OUT="$HOME/.local/share/display-snapshots/$(date +%Y%m%d-%H%M%S)-$TAG"
    mkdir -p "$OUT"

    {
      echo "date:   $(date -Is)"
      echo "kernel: $(uname -r)"
      echo "boot:   $(cat /proc/sys/kernel/random/boot_id 2>/dev/null)"
      echo "cmdline:"; tr ' ' '\n' < /proc/cmdline | sed 's/^/  /'
    } > "$OUT/system.txt" 2>&1

    hyprctl monitors all -j > "$OUT/monitors.json" 2>&1
    hyprctl layers -j      > "$OUT/layers.json"   2>&1
    hyprctl clients -j     > "$OUT/clients.json"  2>&1
    hyprctl workspaces -j  > "$OUT/workspaces.json" 2>&1

    # Human-readable one-liner per output: the thing you actually eyeball first.
    hyprctl monitors all -j | ${pkgs.jq}/bin/jq -r \
      '.[] | "\(.name)\t\(.width)x\(.height)@\(.refreshRate)\tat \(.x),\(.y)\tscale=\(.scale)\ttransform=\(.transform)\tds=\(.directScanoutTo)\tblocked=\(.directScanoutBlockedBy)"' \
      > "$OUT/summary.txt" 2>&1

    # DRM ground truth, below the compositor: connector mode lists, and the
    # CRTC/plane geometry that would show a viewport mismatch if there is one.
    ${lib.getBin pkgs.libdrm}/bin/modetest -M nvidia-drm -c > "$OUT/modetest-connectors.txt" 2>&1
    ${lib.getBin pkgs.libdrm}/bin/modetest -M nvidia-drm -p > "$OUT/modetest-planes.txt" 2>&1

    # EDIDs: raw blobs plus hashes, to catch a chain that enumerates differently
    # on some boots.
    mkdir -p "$OUT/edid"
    for d in /sys/class/drm/card*-*/; do
      c=$(basename "$d")
      [ "$(cat "$d/status" 2>/dev/null)" = connected ] || continue
      cp "$d/edid" "$OUT/edid/$c.bin" 2>/dev/null || true
      printf '%s  %s\n' "$(${pkgs.coreutils}/bin/md5sum < "$d/edid" 2>/dev/null | cut -d' ' -f1)" "$c" >> "$OUT/edid/hashes.txt"
      tr '\n' ' ' < "$d/modes" > "$OUT/edid/$c.modes" 2>/dev/null || true
    done

    # Compositor-side render, to separate "rendered wrong" from "scanned out
    # wrong" -- these have been pixel-perfect every time so far, which is what
    # points below the compositor.
    for m in $(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[].name'); do
      ${pkgs.grim}/bin/grim -o "$m" "$OUT/render-$m.png" 2>/dev/null || true
    done

    LOG=$(ls -t "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/hyprland.log 2>/dev/null | head -1)
    if [ -n "''${LOG:-}" ]; then
      grep -E "Modesetting|wlr_output_manager override|modeline" "$LOG" > "$OUT/hyprland-modeset.txt" 2>&1 || true
      tail -n 2000 "$LOG" > "$OUT/hyprland-tail.log" 2>&1 || true
    fi

    echo "$OUT"
  '';

  # Wallpapers
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
    # Ambient display (DP-1): btop is already in the system profile, cava is
    # not — the dashboard supervisor references both by store path, but having
    # cava on PATH makes it debuggable by hand.
    cava
    btop
    # Captures the full display state (hyprctl, DRM via modetest, EDIDs, and a
    # grim render per output) to ~/.local/share/display-snapshots. Runs once per
    # session automatically; run it by hand after a boot to label one:
    #   display-snapshot good     /  display-snapshot broken
    displaySnapshot
    libdrm      # modetest, for reading DRM state below the compositor
  ];

  xdg.configFile = {

    # ── Palette (still consumed by hyprlock.conf via `source`) ───────────────

    "hypr-hyprlain/assets/palette/palette.conf".text = palette-conf;
    "hypr-hyprlain/assets/palette/palette.css".text  = palette-css;

    # ── Hyprland session config — NEW Lua (Hyprland 0.55) ────────────────────
    # Validated with `Hyprland --verify-config`.

    "hypr-hyprlain/hyprland.lua".text = ''
      -- Hyprlain session — Hyprland 0.55 Lua config (generated by home-manager)

      --------------------- PALETTE ---------------------
      local c = {
        backprimary="000000", backsecondary="1A1A1A", backtertiary="2A2A2A",
        foreprimary="CE7688", foresecondary="BA6A7B", foretertiary="A05969",
        forequaternary="965363", foresenary="804654", foreoctonary="5D333C",
        highprimary="C1B48E",
      }
      local function rgb(hex) return "rgb(" .. hex .. ")" end

      --------------------- MONITORS ---------------------
      -- STAGE 1 BASELINE (2026-08-20). Deliberately back to a single wildcard
      -- rule -- the arrangement that predated the three-monitor work.
      --
      -- Explicit per-output mode/position rules were pinned here to stop the
      -- LG flickering and to detach it from the desk. That config turned out to
      -- be NON-DETERMINISTIC across boots: sometimes every monitor came up
      -- correct, sometimes the LG's image sat in a sub-rectangle of its raster
      -- offset to the bottom-right, and once the main LCD -- which has no
      -- adapters at all -- did the same. Since the fault moves between outputs
      -- and boots, it cannot be reasoned about from a single broken session;
      -- see display-snapshot below, which exists to capture a GOOD boot to diff
      -- against a bad one.
      --
      -- Everything measurable was already ruled out while the LG was broken:
      -- the Hyprland log shows correct modesets, `modetest` shows the CRTC at
      -- the right size with the plane at 0,0, `grim -o DP-1` captures are
      -- pixel-perfect, direct scanout was inactive, there were no
      -- wlr-output-management overrides, and all three EDID hashes were
      -- unchanged. A bare TTY reproduces it with no compositor running at all.
      --
      -- So do NOT re-add per-output rules here without going through the stages
      -- in the plan: pin the LG's mode first, then positions, then the ambient
      -- dashboard, verifying across several boots at each step. Re-adding them
      -- all at once is what made this impossible to attribute.
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

      -- STAGE 2: LG T730SH CRT (ambient display), pinned to 1024x768@75.
      --
      -- The mode matters for TWO independent reasons, and it took a long time
      -- to separate them:
      --
      -- 1. SYNC POLARITY decides whether the image lands correctly on the tube.
      --    A CRT selects its deflection preset from the H/V sync polarity
      --    combination (the old VESA convention). On this monitor the four
      --    1024x768 modes split cleanly:
      --        @85  94.50 MHz  +hsync +vsync   -> correct geometry
      --        @75  78.75 MHz  +hsync +vsync   -> correct geometry
      --        @70  75.00 MHz  -hsync -vsync   -> wrong preset
      --        @60  65.00 MHz  -hsync -vsync   -> wrong preset
      --    Pinning @60 is why the picture sat in a sub-rectangle of the raster,
      --    offset to the bottom-right, with unscanned black around it. It was
      --    never a position, scaling, scanout or compositor problem: `grim`
      --    captures were pixel-perfect, `modetest` showed the CRTC and plane
      --    correct, and a bare TTY reproduced it. Do not "fix" the offset by
      --    moving the output or adjusting the monitor -- the OSD controls just
      --    slide the wrongly-sized raster around, which is exactly what the
      --    symptom looked like.
      --
      -- 2. DOT CLOCK decides whether it holds sync at all. The EDID-preferred
      --    @85 needs 94.50 MHz at 68.677 kHz -- inside the tube's documented
      --    30-71 kHz / 110 MHz limits, but with only ~3% hsync headroom, and it
      --    is reached through two conversion stages (GPU DP -> DP-to-HDMI ->
      --    HDMI-to-VGA) whose converters are specified for standard 60 Hz
      --    timings. At 94.50 MHz they emit marginal sync, the CRT drops lock,
      --    powers down, re-detects, and repeats: the observed flicker.
      --
      -- @75 is the only mode that satisfies both: positive sync like @85, but
      -- 78.75 MHz / 60.023 kHz, a 17% lower dot clock. Confirmed aligned AND
      -- stable on 2026-08-20.
      --
      -- Also worth knowing when reading `hyprctl monitors` for this output: the
      -- 1920x1080@59.94 / 1280x720 / 720x480 entries in availableModes are NOT
      -- the CRT's. The adapter appends its own CTA-861 block (with an HDMI
      -- vendor block and PCM audio descriptors -- a 2006 analog CRT has
      -- neither) on top of the real LG base EDID. Those are 16:9 CE modes the
      -- tube has no preset for, which is why they all landed wrong too.
      -- POSITION: the LG sits at the ORIGIN, and that is load-bearing.
      --
      -- The only configuration ever confirmed both aligned and stable on this
      -- monitor is 1024x768@75 at 0x0. Every misplaced sighting has had DP-1 at
      -- a non-zero x (2390, 5000), and the aligned ones -- the TTY console, the
      -- SDDM greeter, and the one good live test -- all had it at the origin.
      -- The main LCD showed the same fault exactly once, during the only period
      -- it was itself at a non-zero x (1024, under the auto layout).
      --
      -- The failure looks like the scanout being displaced by a large positive
      -- offset rather than anything wrong with the picture: a photo of the tube
      -- shows btop's TOP-LEFT corner rendered in the BOTTOM-RIGHT of the raster
      -- with the remainder clipped off the right and bottom edges, while `grim`
      -- captures of the same output are pixel-perfect and `modetest` reports the
      -- CRTC at the correct size with the plane at 0,0. The offset also exceeds
      -- the monitor's own H/V position range, which is why adjusting geometry on
      -- the OSD only slides the visible fragment around without revealing the
      -- missing content.
      --
      -- So the desk monitors are placed to the RIGHT of the LG rather than the
      -- LG being pushed out past them. This also matches the physical desk:
      -- LG left, S19D300 centre, SyncMaster right.
      --
      -- CONSEQUENCE: the LG is adjacent to the main display, so the pointer can
      -- walk onto a screen only visible from the bed. That is the price of
      -- keeping it usable; isolating the cursor needs a different mechanism than
      -- a coordinate gap (a gap requires a non-zero origin, which is exactly
      -- what breaks it).
      hl.monitor({ output = "${monAmbient}", mode = "1024x768@75",    position = "0x0",    scale = 1 })
      hl.monitor({ output = "${monMain}",    mode = "1366x768@59.79", position = "1024x0", scale = 1 })
      hl.monitor({ output = "${monRight}",   mode = "1024x768@85",    position = "2390x0", scale = 1 })

      --------------------- PER-MONITOR WORKSPACES ---------------------
      -- Pin each monitor its OWN slice of workspaces and make them persistent.
      -- This is what makes SUPER+N deterministic: without pinning, a workspace
      -- migrates to whichever monitor last showed it, so hl.dsp.focus({workspace
      -- =N}) sometimes jumped to the wrong monitor. Pinned + persistent also
      -- means every workspace (and thus every app-icon) is always shown in the
      -- bar, and never gets "stuck" or vanishes.
      --   ${monMain} (centre, main) -> workspaces 1-9
      --   ${monRight} (right, CRT)      -> workspaces 10-18
      --   ${monAmbient} (ambient, CRT)    -> workspaces 19-20, NOT in the SUPER+N rotation
      -- The bases here are generated from the same wsBases attrset that builds
      -- the focus/move scripts, so the two cannot drift apart — that drift is
      -- precisely what broke when the third monitor appeared.
      local monWs = { ${lib.concatStringsSep ", " (lib.mapAttrsToList (out: base: ''["${out}"] = ${toString base}'') wsBases)} }
      for output, base in pairs(monWs) do
        for i = 1, 9 do
          hl.workspace_rule({
            workspace  = tostring(base + i),
            monitor    = output,
            persistent = true,
            default    = (i == 1),
          })
        end
      end

      -- The ambient display's own workspaces, kept outside the 1-18 range so
      -- no SUPER+N combination can land on them by accident.
      --   ${toString wsAmbientDash} = the btop/cava dashboard (default, always occupied)
      --   ${toString wsAmbientMedia} = scratch space for movies thrown over with SUPER+SHIFT+grave
      hl.workspace_rule({ workspace = "${toString wsAmbientDash}",  monitor = "${monAmbient}", persistent = true, default = true })
      hl.workspace_rule({ workspace = "${toString wsAmbientMedia}", monitor = "${monAmbient}", persistent = true, default = false })

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
          -- dim_strength stays 0 as a belt-and-suspenders: this hyprlain build's
          -- `hyprctl reload` won't flip dim_inactive back to false at runtime, so
          -- a bare reload could otherwise re-enable the grey dim. strength 0 makes
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
        -- This was 1, which means "scan out ANY solitary window" -- only 2
        -- ("auto") restricts it to fullscreen game content, so a plain kitty on
        -- a bar-less monitor qualified. Direct scanout is a known source of
        -- artifacts and is off by default upstream for that reason; it is not
        -- the cause of the offset bug (that reproduces with scanout inactive
        -- and on a bare TTY) but it must not be a variable while bisecting.
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
          -- Match the normal session's layout (us + AltGr-intl); do not add a
          -- second layout so the SHIFT+N cycle can't strand you on the wrong one.
          kb_layout = "us",
          kb_variant = "altgr-intl",
          follow_mouse = 1,
          touchpad = { disable_while_typing = false, middle_button_emulation = true, tap_to_click = false },
        },
        animations = { enabled = true },
      })

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
        -- Distinctly classed so the window rule below can pin it to workspace
        -- 1 on the main display. Without that it inherited whatever monitor
        -- happened to be focused at startup — which is DP-1, the ambient LG.
        -- SUPER+Q still launches a plain, unclassed kitty that opens wherever
        -- you currently are.
        hl.exec_cmd("kitty --class hyprlain-term -c " .. home .. "/.config/kitty-hyprlain/kitty.conf")
        hl.exec_cmd("${sessionFocusMain}")
        hl.exec_cmd("dunst -config " .. home .. "/.config/dunst-hyprlain/dunstrc")
        hl.exec_cmd("hypridle -c " .. home .. "/.config/hypr-hyprlain/hypridle.conf")
        -- Holds a Wayland idle inhibitor for as long as anything is playing
        -- audio through PipeWire, so hypridle never dims/locks/suspends during
        -- videos or voice calls. See hypr-hyprlain/idle-inhibit.toml.
        hl.exec_cmd("wayland-pipewire-idle-inhibit -c " .. home .. "/.config/hypr-hyprlain/idle-inhibit.toml")
        hl.exec_cmd("udiskie")
        hl.exec_cmd("nm-applet")
        hl.exec_cmd("systemctl --user start hyprpolkitagent")
        -- Vicinae is a daemon: `vicinae toggle` only shows the window if the
        -- server is already up, so start it here (SUPER+SPACE was a no-op).
        hl.exec_cmd("vicinae server")
        -- Wallpaper: Stylix's hyprpaper target is disabled (see
        -- theme-hyprlain.nix), so this session draws the Hyprlain animated GIF
        -- itself with awww (the renamed swww). The sleep lets the daemon come up
        -- before `awww img` connects to it.
        hl.exec_cmd("awww-daemon")
        hl.exec_cmd("sleep 1.5 && awww img ${wallpaperGif}")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
        -- Ambient dashboard on the LG. One kitty, distinctly classed so the
        -- window rule further down pins it to ws ${toString wsAmbientDash} without catching any
        -- other terminal; the supervisor inside swaps btop <-> cava based on
        -- whether anything is actually playing.
        hl.exec_cmd("kitty --class hyprlain-ambient -c " .. home .. "/.config/kitty-hyprlain/kitty.conf -e ${ambientDash}")

        -- Record display state once per session, ~8s in so every output has
        -- settled and waybar/wallpaper layers exist. See displaySnapshot.
        hl.exec_cmd("sleep 8 && ${displaySnapshot}/bin/display-snapshot session")
      end)

      --------------------- KEYBINDS ---------------------
      local M = "SUPER"
      local home = os.getenv("HOME")  -- also used by the screenshot/wlogout binds below
      local terminal = "kitty -c " .. home .. "/.config/kitty-hyprlain/kitty.conf"
      local browser  = "zen-beta"
      local files    = "dolphin"

      hl.bind(M .. " + Q", hl.dsp.exec_cmd(terminal))
      hl.bind(M .. " + W", hl.dsp.exec_cmd(browser))
      hl.bind(M .. " + E", hl.dsp.exec_cmd(files))
      hl.bind(M .. " + T", hl.dsp.exec_cmd(terminal .. " -e nvim"))
      hl.bind(M .. " + SPACE", hl.dsp.exec_cmd("vicinae toggle"))
      -- (SUPER+9 used to launch Spotify here. It collided head-on with the
      -- SUPER+1..9 workspace loop below, which is registered later and so won
      -- the binding — the Spotify launcher had been dead ever since. Its
      -- "[workspace 9 silent; fullscreen] spotify" prefix was legacy
      -- hyprland.conf dispatcher syntax that this Lua config does not parse
      -- anyway. Moved to SUPER+SHIFT+M, which is free.)
      hl.bind(M .. " + SHIFT + M", hl.dsp.exec_cmd("spotify"))

      hl.bind(M .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker -a -fhex"))
      hl.bind(M .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot --mode=region --freeze --output-folder=" .. home .. "/Media/Screenshots"))
      hl.bind("Print", hl.dsp.exec_cmd("hyprshot --mode=region --freeze --output-folder=" .. home .. "/Media/Screenshots"))
      -- Power / logout overlay (wlogout) — reliable regardless of the Waybar button
      hl.bind(M .. " + ESCAPE", hl.dsp.exec_cmd("wlogout -l " .. home .. "/.config/hypr-hyprlain/wlogout-layout -C " .. home .. "/.config/hypr-hyprlain/wlogout.css"))

      -- pkill (procps), not killall (psmisc, which isn't installed)
      hl.bind(M .. " + O", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
      hl.bind(M .. " + X", hl.dsp.window.close())
      hl.bind(M .. " + F", hl.dsp.window.fullscreen())
      hl.bind(M .. " + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(M .. " + B", hl.dsp.window.pseudo())
      hl.bind(M .. " + N", hl.dsp.layout("togglesplit"))
      hl.bind(M .. " + M", hl.dsp.group.toggle())

      -- Per-monitor workspaces (plugin-free): SUPER+N switches the FOCUSED
      -- monitor to its OWN Nth workspace; SHIFT+N moves the window there.
      -- focusWsHl/moveWsHl compute the global workspace from the focused monitor.
      for i = 1, 9 do
        hl.bind(M .. " + " .. i,         hl.dsp.exec_cmd("${focusWsHl} " .. i))
        hl.bind(M .. " + SHIFT + " .. i, hl.dsp.exec_cmd("${moveWsHl} " .. i))
      end

      -- Ambient display (LG, ws ${toString wsAmbientDash}/${toString wsAmbientMedia}). It is geometrically detached, so
      -- these binds are the ONLY way focus reaches it — no amount of pointer
      -- movement or directional focus will get you there by accident.
      --   SUPER+`         toggle focus to the LG and back to where you came from
      --   SUPER+SHIFT+`   throw the focused window onto the LG's media workspace
      --   SUPER+ALT+`     flip the LG between the dashboard and the media workspace
      hl.bind(M .. " + grave",           hl.dsp.exec_cmd("${ambientToggle}"))
      -- follow = false is essential here. hl.window.move defaults to following
      -- the window (silent is only set when follow is explicitly false), which
      -- would teleport focus and the pointer onto the one monitor that isn't
      -- visible from the desk. Throw the window, stay put, then walk over with
      -- SUPER+grave when you actually want it.
      hl.bind(M .. " + SHIFT + grave",   hl.dsp.window.move({ workspace = ${toString wsAmbientMedia}, follow = false }))
      hl.bind(M .. " + ALT + grave",     hl.dsp.exec_cmd("${ambientFlip}"))
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

      -- SUPER equivalents for 65%/compact keyboards without dedicated media keys
      -- (also reachable by clicking/scrolling the Waybar volume & media modules).
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
      local popups = "feh|mpv|pureref|webcamoid|solaar|psensor|qalculate|iwgtk|easyeffects|desktop-portal|overskride|waypaper|missioncenter"
      hl.window_rule({ name = "popup-class", match = { class = "(?i).*(" .. popups .. ").*" }, float = true, focus_on_activate = true })
      hl.window_rule({ name = "popup-pip",   match = { title = "(?i).*(Picture-in-Picture).*" }, float = true, focus_on_activate = true })
      hl.window_rule({ name = "forced",      match = { class = "(?i).*(hyprpolkitagent).*" }, stay_focused = true, dim_around = true })
      hl.window_rule({ name = "steam-focus",   match = { class = "^(steam)$", title = "^()" }, stay_focused = true })
      hl.window_rule({ name = "steam-minsize", match = { class = "^(steam)$", title = "^()" }, min_size = "1 1" })

      -- The autostarted terminal belongs on the main display's first
      -- workspace, not on whichever monitor Hyprland happened to focus first
      -- (DP-1, since it enumerates as monitor 0).
      hl.window_rule({
        name  = "startup-term",
        match = { class = "^(hyprlain-term)$" },
        workspace = "1",
      })

      -- Ambient dashboard pinned to the LG's dashboard workspace and
      -- explicitly denied initial focus, so launching it at session start
      -- doesn't yank the cursor onto a monitor that isn't visible from the
      -- desk. Chrome is stripped off since nothing there is interacted with.
      hl.window_rule({
        name  = "ambient-dash",
        match = { class = "^(hyprlain-ambient)$" },
        workspace = "${toString wsAmbientDash}",
        no_initial_focus = true,
        border_size = 0,
        rounding = 0,
        no_shadow = true,
      })
    '';

    # ── Kitty (Hyprlain-scoped: launched via `kitty -c` in the session) ──────

    "kitty-hyprlain/kitty.conf".text = ''
      font_family      AdwaitaMono Nerd Font
      font_size        14.0
      cursor_beam_thickness 2.0
      cursor_trail     1
      tab_bar_align    center
      confirm_os_window_close 0

      ${kittyColors}
    '';

    # ── Cava (ambient display visualiser) ────────────────────────────────────
    # Read by the ambient dashboard supervisor via `cava -p`. Palette matches
    # the rest of the Hyprlain theme. `source = auto` resolves to the default
    # sink's monitor, so it follows whatever CamillaDSP profile is active
    # rather than being pinned to one device.

    "cava-hyprlain/config".text = ''
      [general]
      framerate = 60
      autosens = 1
      overshoot = 20
      # 0 = fit as many bars as the terminal is wide. On a 1024x768 CRT that's
      # a dense, full-width spectrum, which is the point of this display.
      bars = 0

      [input]
      method = pipewire
      source = auto

      [output]
      method = ncurses
      channels = stereo
      mono_option = average

      [color]
      background = '#000000'
      foreground = '#CE7688'

      [smoothing]
      noise_reduction = 77
    '';

    # ── Dunst (Hyprlain-scoped: launched via `dunst -config` in the session) ─

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

      listener {
        timeout    = 1800
        on-timeout = systemctl suspend
      }
    '';

    # ── Idle inhibit while audio is playing ─────────────────────────────────
    # hypridle only counts input events as activity, so watching a video or
    # sitting in a voice call without touching the mouse would still dim, lock
    # and eventually suspend. wayland-pipewire-idle-inhibit watches the
    # PipeWire graph and raises a Wayland idle inhibitor whenever a playback
    # stream is running, which hypridle honours.
    #
    # The blacklist matters: any node that streams *continuously* would pin the
    # inhibitor on forever and break suspend entirely. CamillaDSP (audio-eq.nix)
    # is exactly such a node — it is an always-on filter chain, not media.

    "hypr-hyprlain/idle-inhibit.toml".text = ''
      verbosity = "WARN"

      # Ignore blips shorter than this (notification chimes, UI sounds).
      media_minimum_duration = 10

      idle_inhibitor = "wayland"

      [[node_blacklist]]
      name = "(?i)camilladsp"

      [[node_blacklist]]
      app_name = "(?i)camilladsp"
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

    # ── Waybar config ────────────────────────────────────────────────────────

    "waybar-hyprlain/config".text = ''
      {
        "layer": "top",
        "position": "top",
        "height": 24,
        "spacing": 0,
        // Desk monitors only. The LG on DP-1 is a dedicated ambient display
        // (btop/cava, or a movie) viewed from across the room — a status bar
        // there is unreadable clutter, and its workspaces (19/20) are outside
        // the SUPER+N rotation the bar exists to visualise anyway.
        "output": ["HDMI-A-1", "DP-3"],
        // Upstream Hyprlain pins a fixed "width": 1431 to make the bar a
        // centered portion. Our monitors (1366 and 1024) are narrower, so a
        // fixed width would overflow to full-width; symmetric 40px margins
        // (upstream's own per-side gap) give the same inset look on both.
        "margin-left": 40,
        "margin-right": 40,
        "modules-left": [
          "hyprland/workspaces"
        ],
        "modules-center": [
          "hyprland/window"
        ],
        "modules-right": [
          "mpris",
          "custom/eq",
          "pulseaudio",
          "network",
          "clock",
          "group/hiddentray",
          "custom/power"
        ],
        // Faithful to upstream: cpu/temperature/memory + the tray are stashed in
        // a drawer behind the "eye" (custom/expand) toggle, next to power.
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
        // NOTE: all glyphs are JSON \uXXXX escapes on purpose. Literal Nerd-Font
        // private-use chars embedded in this Nix heredoc get silently stripped
        // to empty strings (that's why cpu/mem/workspace icons were blank).
        // Icons mirror per monitor: mon0 owns ws 1-9, mon1 owns ws 10-18, and
        // 10-18 repeat the 1-9 app-icon scheme so each bar reads the same:
        // terminal, browser, code, 4-8 boxes, spotify.
        "hyprland/workspaces": {
          "active-only": false,
          "all-outputs": false,
          "disable-scroll": true,
          "warp-on-scroll": false,
          "format": "{icon}",
          "format-icons": {
            "1": "\uf120",  "2": "\uf269",  "3": "\uf121",
            "4": "\udb83\udca6", "5": "\udb83\udca8", "6": "\udb83\udcaa",
            "7": "\udb83\udcac", "8": "\udb83\udcae", "9": "\uf1bc",
            "10": "\uf120", "11": "\uf269", "12": "\uf121",
            "13": "\udb83\udca6", "14": "\udb83\udca8", "15": "\udb83\udcaa",
            "16": "\udb83\udcac", "17": "\udb83\udcae", "18": "\uf1bc",
            "urgent": "\uf06a",
            "focused": "\uf192",
            "default": "\uf111"
          }
        },
        "hyprland/window": {
          "format": " {title} ",
          "separate-outputs": true
        },
        "pulseaudio": {
          "format": "{icon}",
          "format-bluetooth": "\uf294{icon}{volume}%",
          "format-muted": "\ueee8",
          "format-icons": {
            "default": ["\uf027", "\uf028"],
            "speaker": ["\uf027", "\uf028"],
            "speaker-muted": "\ueee8\ue32d",
            "headphone": "\uf025",
            "hands-free": "\udb86\udc4f",
            "headset": "\udb80\udece",
            "phone": "\uf095",
            "phone-muted": "\ued17",
            "portable": "\uf095",
            "car": "\uf1b9"
          },
          "scroll-step": 1,
          "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
          "max-volume": 150,
          "tooltip-format": "{icon} {volume}% \u2014 scroll to change, click to mute"
        },
        // Cycles the CamillaDSP AutoEQ profile: Speakers 5.1 (passthrough) ->
        // Headphones Flat -> Headphones Harman IE 2019 -> back to Speakers.
        // Also flips the CM106 card's ACP profile (5.1 vs stereo) to match.
        "custom/eq": {
          "exec": "eq-status",
          "return-type": "json",
          "on-click": "eq-switch cycle",
          "signal": 8,
          "interval": 30
        },
        "mpris": {
          "format": "{player_icon} {title}",
          "format-paused": "{status_icon} {title}",
          "player-icons": { "default": "\uf001", "spotify": "\uf1bc" },
          "status-icons": { "paused": "\uf04c" },
          "max-length": 28,
          "on-click": "playerctl play-pause",
          "on-scroll-up": "playerctl next",
          "on-scroll-down": "playerctl previous",
          "tooltip-format": "{title} \u2014 {artist}"
        },
        "network": {
          "family": "ipv4",
          "format-ethernet": "\udb80\ude00",
          "format-wifi": "{icon}",
          "format-linked": "\udb85\ude16",
          "format-disconnected": "\udb82\udd2e",
          "format-icons": ["\udb82\udd2b", "\udb82\udd2f", "\udb82\udd1f", "\udb82\udd22", "\udb82\udd25", "\udb82\udd28"],
          "on-click-right": "iwgtk",
          "tooltip-format": "{icon} {signalStrength}% [{essid} - {ifname}] {frequency}GHz\n{ipaddr}/{cidr}\nUP[{bandwidthUpBits}] DWN[{bandwidthDownBits}]\nGATEWAY: {gwaddr}",
          "format-alt": "{icon} {signalStrength}%"
        },
        "clock": {
          "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
          "format-alt": "{:%Y-%m-%d}"
        },
        "temperature": {
          "thermal-zone": 2,
          "critical-threshold": 80,
          "format": "{icon}",
          "format-critical": "{temperatureC}\u00b0C {icon}",
          "format-icons": ["\uf2cb", "\uf2ca", "\uf2c9", "\uf2c7"],
          "on-click-right": "missioncenter"
        },
        "custom/expand": {
          "format": " ",
          "tooltip": "Show cpu / temp / memory / tray"
        },
        "cpu": {
          "format": "\uf2db",
          "tooltip": true,
          "format-icons": ["\u2581", "\u2582", "\u2583", "\u2584", "\u2585", "\u2586", "\u2587", "\u2588"],
          "on-click-right": "hyprsysteminfo"
        },
        "memory": {
          "format": "\uf1c0",
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
          "format": "\u23fb",
          "tooltip": false,
          "on-click": "wlogout -l ~/.config/hypr-hyprlain/wlogout-layout -C ~/.config/hypr-hyprlain/wlogout.css"
        }
      }
    '';

    # ── Waybar style ─────────────────────────────────────────────────────────

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
      #custom-eq   { padding: 0px 10px 0px 0px; }

      /* The power button had no padding *and* its Nerd-Font glyph rendered as a
         near-zero-width sliver on one monitor and an invisible-but-clickable box
         on the other. Use a plain Unicode power symbol (⏻) with an explicit
         min-width so it's always a visible, easy-to-hit target on both bars. */
      #custom-power {
        color: @foreprimary;
        min-width: 22px;
        padding: 0px 14px 0px 10px;
      }
      #clock       { padding: 0px 3px 0px 0px; }

      /* The "eye" drawer toggle (custom/expand) uses the characteristic Lain
         eye image as its icon (not a font glyph), painted as a background so it
         reveals the cpu/temp/memory/tray drawer next to the power button.
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
      #privacy-item.screenshare,
      #privacy-item.audio-out {
        -gtk-icon-effect: highlight;
        background-color: @foresecondary;
      }
    '';

    # ── Wlogout style with real Hyprlain GIF icons ───────────────────────────

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

    # ── Wlogout layout ───────────────────────────────────────────────────────
    # The default layout's logout action is `loginctl terminate-user $USER`,
    # which under a uwsm-managed session tears the user manager down hard and
    # leaves the VT at a blinking cursor instead of returning to SDDM. `uwsm
    # stop` stops the compositor's systemd scope gracefully, so SDDM reclaims
    # the VT. Pass this with `wlogout -l ~/.config/hypr-hyprlain/wlogout-layout`.
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
