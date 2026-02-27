{ config, pkgs, username, ... }:

{
  # Define user account
  users.users.${username} = {
    isNormalUser = true;
    description = "Maru Olcese";
    extraGroups = [ 
      "wheel"         # sudo access
      "networkmanager"
      "video"
      "audio"
      "input"
      "realtime"
    ];
    
    # User's home will be on /persist
    home = "/home/${username}";
    
    # Set a password (you'll change this after installation)
    initialPassword = "12345";
    
    shell = pkgs.zsh;
  };
  
  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Ensure realtime limits for audio users
  environment.etc."security/limits.d/audio.conf".text = ''@audio - rtprio 90'';
  
  # Persist user home directory
  environment.persistence."/persist" = {
    users.${username} = {
      directories = [
        "Documents"
        "Downloads"
        "Music"
        "Pictures"
        "Videos"
        "Projects"
        ".ssh"
        ".local/share"
        ".cache"
        ".config"
        
        # Development
        ".cargo"
        ".rustup"
        
        # Other persistent dirs you might want
        # ".mozilla"
        # ".thunderbird"
      ];
    };
  };
  
  # Link home to /persist/home
  fileSystems."/home/${username}" = {
    device = "/persist/home/${username}";
    options = [ "bind" ];
    neededForBoot = true;
    depends = [ "/persist" ];
  };
}
