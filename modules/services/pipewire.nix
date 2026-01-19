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
  };
  
  # Disable PulseAudio (replaced by PipeWire)
  hardware.pulseaudio.enable = false;
}
