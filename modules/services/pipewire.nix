{ config, ... }:

{
  # PipeWire audio
  security.rtkit.enable = true;
  
  services.pipewire = {
    enable = true;
    
    # ALSA support
    alsa = {
      enable = true;
      support32Bit = true;
    };
    
    # PulseAudio compatibility
    pulse.enable = true;
    
    # JACK support
    jack.enable = true;

    # Static virtual sink for the CamillaDSP AutoEQ chain (see
    # home/modules/desktop/audio-eq.nix). Apps play into this; eq-link
    # (re)links its monitor ports directly into whichever CamillaDSP
    # capture node is currently active.
    #
    # This used to be `pw-loopback` (or the equivalent
    # libpipewire-module-loopback loaded into the running daemon), which
    # creates a *bidirectional bridge* — a paired capture+playback stream
    # internally forwarding between them. Both were tested extensively and
    # both reproducibly broke actual audio output on this hardware (a cheap
    # CM6206-based USB 5.1 dongle): PipeWire's own graph showed real,
    # correctly-leveled audio data flowing all the way to the hardware sink
    # object, camilladsp logged no errors, yet nothing was audible except a
    # brief moment right as a stream was freshly (re)connected — consistent
    # with a USB Audio Class device's clock/PLL losing lock under whatever
    # timing the bridge's internal forwarding introduces. A single-hop
    # direct pw-link (no bridge) was the only thing that reliably produced
    # continuous audible sound in testing.
    #
    # A plain `support.null-audio-sink` adapter has no such bridge — it's
    # just an Audio/Sink with a monitor tap, structurally the same as a
    # single-hop link once its monitor is pw-linked onward (which eq-link
    # does). `object.linger = true` keeps it alive independent of any
    # client connection lifetime (the standard pattern for PipeWire's own
    # documented virtual-device examples).
    extraConfig.pipewire."99-eq-null-sink" = {
      context.objects = [
        {
          factory = "adapter";
          args = {
            "factory.name" = "support.null-audio-sink";
            "node.name" = "eq-null-sink";
            "node.description" = "EQ Input";
            "media.class" = "Audio/Sink";
            "audio.channels" = 6;
            "audio.position" = "FL,FR,FC,LFE,RL,RR";
            "node.autoconnect" = false;
            "object.linger" = true;
          };
        }
      ];
    };
  };
  
  # Disable PulseAudio (replaced by PipeWire)
  services.pulseaudio.enable = false;
}
