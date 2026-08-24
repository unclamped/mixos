{ config, pkgs, username, ... }:

{
  age.identityPaths = [ "/home/${username}/.config/age/keys.txt" ];

  age.secrets.maru-password = {
    file = ../../secrets/maru-password.age;
  };

  # SSH private key, decrypted straight to ~/.ssh on every boot instead of
  # riding along in plaintext inside the generic .ssh persistence bind-mount
  # (see the files = [...] list below: everything else in .ssh is still
  # plainly persisted since it isn't sensitive).
  age.secrets.ssh-id-ed25519 = {
    file = ../../secrets/ssh-id-ed25519.age;
    path = "/home/${username}/.ssh/id_ed25519";
    owner = username;
    group = "users";
    mode = "0600";
  };

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
      "docker"
    ];
    
    # User's home will be on /persist
    home = "/home/${username}";
    
    hashedPasswordFile = config.age.secrets.maru-password.path;
    
    shell = pkgs.zsh;
  };
  
  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Don't nag on every new terminal
  security.sudo.extraConfig = "Defaults lecture=never";

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

      # .ssh/id_ed25519 (the private key) comes from the age secret above
      # instead of being persisted here in plaintext.
      files = [
        ".ssh/id_ed25519.pub"
        ".ssh/known_hosts"
        ".ssh/config"
      ];
    };
  };
  
  # Link home to /persist/home
  fileSystems."/home/${username}" = {
    device = "/persist/home/${username}";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
    depends = [ "/persist" ];
  };
}
