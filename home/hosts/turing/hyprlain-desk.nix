{ config, pkgs, lib, ... }:

# turing's Hyprlain session: the three-monitor desk.
#
# Everything visual/behavioural that turing shares with cerf lives in
# home/modules/desktop/hyprlain — this file only supplies what is genuinely
# specific to THIS desk: named outputs, the per-monitor workspace slicing that
# makes SUPER+N act on the focused monitor, and the ambient CRT with its
# auto-switching btop/cava dashboard.

let
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

in
{
  hyprlain = {
    enable = true;
    description = "turing (three-monitor desk), Hyprland Lua config";

    extraPackages = with pkgs; [
      # Ambient display (DP-1): btop is already in the system profile, cava is
      # not — the dashboard supervisor references both by store path, but
      # having cava on PATH makes it debuggable by hand.
      cava
      btop
      # Captures the full display state (hyprctl, DRM via modetest, EDIDs, and
      # a grim render per output) to ~/.local/share/display-snapshots. Runs
      # once per session automatically; run it by hand after a boot to label
      # one:  display-snapshot good  /  display-snapshot broken
      displaySnapshot
      libdrm      # modetest, for reading DRM state below the compositor
    ];

    kitty.fontSize = "14.0";

    # A desktop on permanent AC: give it a long leash before suspending.
    idle.suspendTimeout = 1800;
    # CamillaDSP (audio-eq.nix) is an always-on filter chain that appears in
    # the PipeWire graph as a permanently running playback stream. Left
    # unblacklisted it pins the idle inhibitor on forever and the machine
    # never suspends at all.
    idle.blacklist = ''
      [[node_blacklist]]
      name = "(?i)camilladsp"

      [[node_blacklist]]
      app_name = "(?i)camilladsp"
    '';

    waybar = {
      # Desk monitors only. The LG on DP-1 is a dedicated ambient display
      # (btop/cava, or a movie) viewed from across the room — a status bar
      # there is unreadable clutter, and its workspaces (19/20) are outside
      # the SUPER+N rotation the bar exists to visualise anyway.
      outputs = [ monMain monRight ];
      # Upstream Hyprlain pins a fixed "width": 1431 to make the bar a centred
      # portion. These monitors (1366 and 1024) are narrower, so a fixed width
      # would overflow to full-width; symmetric 40px margins (upstream's own
      # per-side gap) give the same inset look on both.
      margin = 40;
      modulesRight = [ "mpris" "custom/eq" "pulseaudio" "network" "clock" "group/hiddentray" "custom/power" ];
      # Icons mirror per monitor: mon0 owns ws 1-9, mon1 owns ws 10-18, and
      # 10-18 repeat the 1-9 app-icon scheme so each bar reads the same:
      # terminal, browser, code, 4-8 boxes, spotify.
      workspaceIcons = ''
        "1": "\uf120",  "2": "\uf269",  "3": "\uf121",
        "4": "\udb83\udca6", "5": "\udb83\udca8", "6": "\udb83\udcaa",
        "7": "\udb83\udcac", "8": "\udb83\udcae", "9": "\uf1bc",
        "10": "\uf120", "11": "\uf269", "12": "\uf121",
        "13": "\udb83\udca6", "14": "\udb83\udca8", "15": "\udb83\udcaa",
        "16": "\udb83\udcac", "17": "\udb83\udcae", "18": "\uf1bc",
        "urgent": "\uf06a",
        "focused": "\uf192",
        "default": "\uf111"
      '';
      temperature = ''
        "thermal-zone": 2,
        "critical-threshold": 80,
        "format": "{icon}",
        "format-critical": "{temperatureC}°C {icon}",
        "format-icons": ["", "", "", ""],
        "on-click-right": "missioncenter"
      '';
      # Cycles the CamillaDSP AutoEQ profile: Speakers 5.1 (passthrough) ->
      # Headphones Flat -> Headphones Harman IE 2019 -> back to Speakers.
      # Also flips the CM106 card's ACP profile (5.1 vs stereo) to match.
      extraModules = ''
        "custom/eq": {
          "exec": "eq-status",
          "return-type": "json",
          "on-click": "eq-switch cycle",
          "signal": 8,
          "interval": 30
        },
      '';
      extraStyle = ''
        #custom-eq { padding: 0px 10px 0px 0px; }
      '';
    };

    lua = {
      browser = "zen-beta";
      popupClasses = "feh|mpv|pureref|webcamoid|solaar|psensor|qalculate|iwgtk|easyeffects|desktop-portal|overskride|waypaper|missioncenter";

      monitors = ''
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
      '';

      workspaceRules = ''
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
      '';

      autostart = ''
        hl.exec_cmd("${sessionFocusMain}")
        -- Ambient dashboard on the LG. One kitty, distinctly classed so the
        -- window rule further down pins it to ws ${toString wsAmbientDash}
        -- without catching any other terminal; the supervisor inside swaps
        -- btop <-> cava based on whether anything is actually playing.
        hl.exec_cmd("kitty --class hyprlain-ambient -c " .. home .. "/.config/kitty-hyprlain/kitty.conf -e ${ambientDash}")
        -- Record display state once per session, ~8s in so every output has
        -- settled and waybar/wallpaper layers exist. See displaySnapshot.
        hl.exec_cmd("sleep 8 && ${displaySnapshot}/bin/display-snapshot session")
      '';

      # Per-monitor workspaces (plugin-free): SUPER+N switches the FOCUSED
      # monitor to its OWN Nth workspace; SHIFT+N moves the window there.
      # focusWsHl/moveWsHl compute the global workspace from the focused
      # monitor, using the same wsBases attrset that pins the workspace rules,
      # so the two cannot drift apart.
      workspaceBinds = ''
        for i = 1, 9 do
          hl.bind(M .. " + " .. i,         hl.dsp.exec_cmd("${focusWsHl} " .. i))
          hl.bind(M .. " + SHIFT + " .. i, hl.dsp.exec_cmd("${moveWsHl} " .. i))
        end
      '';

      binds = ''
        -- (SUPER+9 used to launch Spotify. It collided head-on with the
        -- SUPER+1..9 workspace loop, which is registered later and so won the
        -- binding — the Spotify launcher had been dead ever since. Moved to
        -- SUPER+SHIFT+M, which is free.)
        hl.bind(M .. " + SHIFT + M", hl.dsp.exec_cmd("spotify"))

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
      '';

      windowRules = ''
        hl.window_rule({ name = "steam-focus",   match = { class = "^(steam)$", title = "^()" }, stay_focused = true })
        hl.window_rule({ name = "steam-minsize", match = { class = "^(steam)$", title = "^()" }, min_size = "1 1" })

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
    };
  };

  # ── Cava (ambient display visualiser) ───────────────────────────────────
  # Read by the ambient dashboard supervisor via `cava -p`. Palette matches
  # the rest of the Hyprlain theme. `source = auto` resolves to the default
  # sink's monitor, so it follows whatever CamillaDSP profile is active rather
  # than being pinned to one device.
  xdg.configFile = {
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
  };
}
