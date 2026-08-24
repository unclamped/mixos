{ config, pkgs, lib, ... }:

let
  # nixpkgs' camilladsp is built with only its default cargo features
  # (websocket), so the PipeWire backend ("type: PipeWire" in devices:) is
  # missing from the stock binary — confirmed via `camilladsp --check`
  # listing only ALSA/RawFile/WavFile/STDIN/SignalGenerator as valid capture
  # types. Rebuild with the pipewire-backend feature; the `pipewire` crate is
  # already resolved in nixpkgs' vendored Cargo.lock, it's just gated behind
  # this flag.
  camilladsp = pkgs.camilladsp.overrideAttrs (old: {
    # `buildFeatures` is consumed by buildRustPackage before the derivation is
    # built, so overriding it via overrideAttrs is a no-op — cargoBuildFlags
    # is the actual derivation attribute the build phase reads.
    cargoBuildFlags = (old.cargoBuildFlags or [ ]) ++ [ "--features" "pipewire-backend" ];
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.pipewire ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
  });

  # ICUSBAUDIO7D / "CM106 Like Sound Device" (C-Media CM6206, 0d8c:0102). It
  # exposes both a 2-channel "analog-stereo" ACP profile (headphones plugged
  # into the volume-wheel pod) and a 6-channel "analog-surround-51" profile —
  # confirmed via `wpctl inspect` on the card's Device object (id varies per
  # session, looked up dynamically by eq-switch below).
  cmSinkBase = "alsa_output.usb-0d8c_USB_Sound_Device-00";

  # The app-facing virtual sink ("eq-null-sink", declared statically in
  # modules/services/pipewire.nix) is a single long-lived node, always
  # 6-channel, never recreated on a mode switch — restarting it (as an
  # earlier version of this did, first via `pw-loopback`, then via
  # libpipewire-module-loopback) destroys and recreates the sink object,
  # orphaning whatever's already playing into it (observed: audio plays for
  # a split second right as you switch, then silence — the app's stream
  # doesn't follow to the new node). So every CamillaDSP config's *capture*
  # side is 6-channel to match, regardless of mode; headphone configs
  # downmix 6->2 in their own pipeline before EQing. Only the *playback*
  # side (to real hardware) varies with the mode.
  mkConfig = { name, description, playbackChannels, autoconnectSuffix, extra ? "" }:
    pkgs.writeText "camilladsp-${name}.yml" ''
      devices:
        samplerate: 48000
        chunksize: 1024
        capture:
          type: PipeWire
          channels: 6
          node_name: "eq-${name}"
          node_description: "${description}"
        playback:
          type: PipeWire
          channels: ${toString playbackChannels}
          node_name: "eq-${name}-out"
          node_description: "${description} Output"
          autoconnect_to: "${cmSinkBase}.${autoconnectSuffix}"
      ${extra}
    '';

  # Pure passthrough — no measurement data to justify any speaker correction.
  speakersConfig = mkConfig {
    name = "speakers-51";
    description = "Speakers 5.1 (EQ)";
    playbackChannels = 6;
    autoconnectSuffix = "analog-surround-51";
  };

  # KZ EDX Pro AutoEQ ParametricEQ.txt, converted to CamillaDSP Biquad
  # filters (PK -> Peaking, LSC -> Lowshelf, HSC -> Highshelf) applied
  # identically to both channels, after downmixing the persistent sink's 6
  # incoming channels down to the front L/R pair. Source: autoeq.app
  # "Parametric EQ" export.
  mkHeadphoneFilters = { preamp, bands }:
    let
      filterEntry = b: ''
        f${toString b.n}:
            type: Biquad
            parameters:
              type: ${b.type}
              freq: ${toString b.freq}
              gain: ${toString b.gain}
              q: ${toString b.q}'';
      names = builtins.concatStringsSep ", " (map (b: "f${toString b.n}") bands);
    in ''
      mixers:
        downmix:
          channels:
            in: 6
            out: 2
          mapping:
            - dest: 0
              sources:
                - channel: 0
                  gain: 0
                  inverted: false
            - dest: 1
              sources:
                - channel: 1
                  gain: 0
                  inverted: false

      filters:
        preamp:
          type: Gain
          parameters:
            gain: ${toString preamp}
            inverted: false
            mute: false
      ${builtins.concatStringsSep "\n" (map (b: "  " + filterEntry b) bands)}

      pipeline:
        - type: Mixer
          name: downmix
        - type: Filter
          channels: [0, 1]
          names: [preamp, ${names}]
    '';

  headphonesFlatConfig = mkConfig {
    name = "headphones-flat";
    description = "Headphones - Flat (EQ)";
    playbackChannels = 2;
    autoconnectSuffix = "analog-stereo";
    extra = mkHeadphoneFilters {
      preamp = -11.26;
      bands = [
        { n = 1; type = "Lowshelf"; freq = 105.0; gain = -7.2; q = 0.70; }
        { n = 2; type = "Peaking"; freq = 774.2; gain = 6.2; q = 0.79; }
        { n = 3; type = "Peaking"; freq = 2227.0; gain = -8.3; q = 1.75; }
        { n = 4; type = "Peaking"; freq = 4927.6; gain = -7.2; q = 5.12; }
        { n = 5; type = "Highshelf"; freq = 10000.0; gain = 11.2; q = 0.70; }
      ];
    };
  };

  headphonesHarmanConfig = mkConfig {
    name = "headphones-harman";
    description = "Headphones - Harman IE 2019 (EQ)";
    playbackChannels = 2;
    autoconnectSuffix = "analog-stereo";
    extra = mkHeadphoneFilters {
      preamp = -3.33;
      bands = [
        { n = 1; type = "Lowshelf"; freq = 105.0; gain = -0.7; q = 0.70; }
        { n = 2; type = "Peaking"; freq = 157.0; gain = -4.2; q = 0.56; }
        { n = 3; type = "Peaking"; freq = 757.0; gain = 3.0; q = 1.58; }
        { n = 4; type = "Peaking"; freq = 10000.0; gain = 4.0; q = 0.42; }
        { n = 5; type = "Highshelf"; freq = 10000.0; gain = -2.3; q = 0.70; }
      ];
    };
  };

  # Single source of truth for the three switchable modes, shared by
  # eq-switch and eq-link below so their bash associative arrays can't
  # drift out of sync.
  modes = {
    speakers = {
      config = speakersConfig;
      profile = "output:analog-surround-51+input:analog-stereo";
      autoconnectSuffix = "analog-surround-51";
      target = "eq-speakers-51";
    };
    flat = {
      config = headphonesFlatConfig;
      profile = "output:analog-stereo";
      autoconnectSuffix = "analog-stereo";
      target = "eq-headphones-flat";
    };
    harman = {
      config = headphonesHarmanConfig;
      profile = "output:analog-stereo";
      autoconnectSuffix = "analog-stereo";
      target = "eq-headphones-harman";
    };
  };
  modeOrder = [ "speakers" "flat" "harman" ];

  mkAssoc = field:
    builtins.concatStringsSep "\n"
      (lib.mapAttrsToList (k: v: "  [${k}]=\"${toString v.${field}}\"") modes);

  eqSwitch = pkgs.writeShellApplication {
    name = "eq-switch";
    runtimeInputs = [ pkgs.jq pkgs.wireplumber pkgs.pipewire pkgs.systemd ];
    text = ''
      RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/tmp}"
      ACTIVE_LINK="$RUNTIME_DIR/camilladsp-active.yml"
      STATE_FILE="$RUNTIME_DIR/camilladsp-mode"
      CARD_NAME="alsa_card.usb-0d8c_USB_Sound_Device-00"

      declare -A CONFIGS=(
      ${mkAssoc "config"}
      )
      declare -A PROFILES=(
      ${mkAssoc "profile"}
      )
      declare -A AUTOCONNECT=(
      ${mkAssoc "autoconnectSuffix"}
      )
      ORDER=(${builtins.concatStringsSep " " modeOrder})

      current_mode() {
        if [[ -r "$STATE_FILE" ]]; then cat "$STATE_FILE"; fi
      }

      next_mode() {
        local cur idx next
        cur="$(current_mode)"
        if [[ -z "$cur" ]]; then echo "speakers"; return; fi
        for idx in "''${!ORDER[@]}"; do
          if [[ "''${ORDER[$idx]}" == "$cur" ]]; then
            next=$(( (idx + 1) % ''${#ORDER[@]} ))
            echo "''${ORDER[$next]}"
            return
          fi
        done
        echo "speakers"
      }

      REQUESTED="''${1:-cycle}"
      case "$REQUESTED" in
        cycle) MODE="$(next_mode)" ;;
        ensure)
          MODE="$(current_mode)"
          if [[ -z "$MODE" ]]; then MODE="speakers"; fi
          ;;
        speakers|flat|harman) MODE="$REQUESTED" ;;
        *)
          echo "usage: eq-switch <speakers|flat|harman|cycle|ensure>" >&2
          exit 1
          ;;
      esac

      # Device id and profile index are per-session PipeWire object ids, so
      # they're resolved by name/description on every call rather than
      # hardcoded.
      DEVICE_ID=$(pw-dump | jq -r --arg name "$CARD_NAME" \
        '.[] | select(.info.props["device.name"]? == $name) | .id' | head -n1)

      # wait_for_node <jq-filter>: polls pw-dump for a node matching the
      # given jq boolean filter (applied to each element, "." bound to it)
      # and prints its id once found. Starting a client whose explicit
      # target.object isn't registered yet causes PipeWire to silently fall
      # back to the current default node instead, and that mislink is sticky
      # (it won't self-correct once the real target shows up later) — this
      # bit us in testing, so every dependent step waits for its actual
      # dependency to exist first (see eq-link for the rest of the chain).
      wait_for_node() {
        local filter="$1" id=""
        for _ in $(seq 1 40); do
          id=$(pw-dump | jq -r "[.[] | select($filter)] | .[0].id // empty")
          if [[ -n "$id" ]]; then echo "$id"; return 0; fi
          sleep 0.25
        done
        return 1
      }

      if [[ -n "$DEVICE_ID" ]]; then
        PROFILE_NAME="''${PROFILES[$MODE]}"
        PROFILE_INDEX=$(pw-dump | jq -r --arg id "$DEVICE_ID" --arg name "$PROFILE_NAME" \
          '.[] | select((.id|tostring) == $id) | .info.params.EnumProfile[]? | select(.name == $name) | .index' | head -n1)
        if [[ -n "$PROFILE_INDEX" ]]; then
          wpctl set-profile "$DEVICE_ID" "$PROFILE_INDEX"
          wait_for_node ".info.props[\"device.name\"]? == \"$CARD_NAME\" and (.info.params.Profile[0].index // -1) == $PROFILE_INDEX" \
            >/dev/null || true
        fi
      fi

      ln -sf "''${CONFIGS[$MODE]}" "$ACTIVE_LINK"
      echo "$MODE" > "$STATE_FILE"

      if [[ "$REQUESTED" != "ensure" ]]; then
        # CamillaDSP's playback autoconnect_to only resolves correctly if its
        # hardware target already exists (see wait_for_node above), so stop
        # it and wait for the just-selected ALSA profile's sink node before
        # restarting it. camilladsp.service's own ExecStartPost (eq-link)
        # handles the rest of the chain: waiting for CamillaDSP's capture
        # node, re-linking eq-null-sink, and setting the default sink — the
        # same sequence runs uniformly on boot and here.
        systemctl --user stop camilladsp.service
        wait_for_node ".info.props[\"node.name\"]? == \"${cmSinkBase}.''${AUTOCONNECT[$MODE]}\"" \
          >/dev/null || true
        systemctl --user restart camilladsp.service
      fi
    '';
  };

  eqLink = pkgs.writeShellApplication {
    name = "eq-link";
    runtimeInputs = [ pkgs.jq pkgs.wireplumber pkgs.pipewire pkgs.systemd ];
    text = ''
      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/camilladsp-mode"
      MODE="$(cat "$STATE_FILE" 2>/dev/null || echo speakers)"

      declare -A TARGETS=(
      ${mkAssoc "target"}
      )
      declare -A AUTOCONNECT=(
      ${mkAssoc "autoconnectSuffix"}
      )
      TARGET="''${TARGETS[$MODE]}"
      HW_SINK="${cmSinkBase}.''${AUTOCONNECT[$MODE]}"

      wait_for_node() {
        local filter="$1" id=""
        for _ in $(seq 1 40); do
          id=$(pw-dump | jq -r "[.[] | select($filter)] | .[0].id // empty")
          if [[ -n "$id" ]]; then echo "$id"; return 0; fi
          sleep 0.25
        done
        return 1
      }

      wait_for_node ".info.props[\"node.name\"]? == \"$TARGET\"" >/dev/null

      # eq-null-sink is a static, persistent virtual device declared in
      # PipeWire's own config (modules/services/pipewire.nix) — never
      # created or restarted here, only re-linked to whichever capture node
      # is now active. Its old link (to the previous mode's now-destroyed
      # capture node) is cleaned up automatically by PipeWire when that
      # node disappears, so only the new link needs establishing. Node-level
      # pw-link auto-pairs same-named channels (monitor_FL -> input_FL,
      # etc).
      SINK_ID=$(wait_for_node ".info.props[\"node.name\"]? == \"eq-null-sink\" and .info.props[\"media.class\"]? == \"Audio/Sink\"")
      if [[ -n "$SINK_ID" ]]; then
        pw-link "eq-null-sink" "$TARGET" 2>/dev/null || true
      fi

      # CamillaDSP's own playback->hardware autoconnect (its YAML
      # autoconnect_to) is equally unreliable, and worse than just failing
      # silently: it only sets the PipeWire-level target.object property +
      # StreamFlags::AUTOCONNECT (target_id itself is passed as None — see
      # pipewire_backend/device.rs), and WirePlumber's policy engine
      # re-evaluates that asynchronously whenever a new sink appears —
      # observed linking CamillaDSP's playback into our own EQ sink instead
      # (a feedback loop that never reaches real hardware). So this runs
      # last, once everything else has settled, and force-corrects it:
      # disconnect any stray link into our own sink, then link to hardware
      # explicitly.
      pw-link -d "$TARGET-out" "eq-null-sink" 2>/dev/null || true
      pw-link "$TARGET-out" "$HW_SINK" 2>/dev/null || true

      if [[ -n "$SINK_ID" ]]; then
        wpctl set-default "$SINK_ID"
      fi

      pkill -RTMIN+8 waybar 2>/dev/null || true
    '';
  };

  eqStatus = pkgs.writeShellApplication {
    name = "eq-status";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      STATE_FILE="''${XDG_RUNTIME_DIR:-/tmp}/camilladsp-mode"
      mode="$(cat "$STATE_FILE" 2>/dev/null || echo speakers)"

      # Nerd Font PUA glyphs (fa-volume-up / fa-headphones), matching the
      # rest of the hyprlain waybar iconography.
      speaker_icon=$(printf '')
      headphones_icon=$(printf '')

      case "$mode" in
        speakers) icon="$speaker_icon";    label="Speakers 5.1 (passthrough)" ;;
        flat)     icon="$headphones_icon F"; label="Headphones — Flat target" ;;
        harman)   icon="$headphones_icon H"; label="Headphones — Harman IE 2019 target" ;;
        *)        icon="$headphones_icon";  label="EQ" ;;
      esac

      jq -nc --arg text "$icon" --arg tooltip "$label — click to switch" \
        '{text: $text, tooltip: $tooltip}'
    '';
  };
in
{
  home.packages = [ camilladsp pkgs.pipewire pkgs.jq eqSwitch eqStatus ];

  systemd.user.services.camilladsp = {
    Unit = {
      Description = "CamillaDSP audio EQ engine";
      After = [ "pipewire.service" "wireplumber.service" ];
      PartOf = [ "pipewire.service" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${eqSwitch}/bin/eq-switch ensure";
      ExecStart = ''${camilladsp}/bin/camilladsp -p 1234 -w "%t/camilladsp-active.yml"'';
      ExecStartPost = "${eqLink}/bin/eq-link";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "pipewire.service" ];
  };
}
