{ config, pkgs, username, ... }:

{
  age.identityPaths = [ "/home/${username}/.config/age/keys.txt" ];

  age.secrets.maru-password = {
    file = ../../secrets/maru-password.age;
  };

  # SSH private key, decrypted straight to ~/.ssh on every boot instead of
  # riding along in plaintext. Everything else in ~/.ssh persists plainly
  # since it isn't sensitive — the whole home directory is bind-mounted from
  # /persist/home/${username} below, so no per-file persistence entry is
  # needed for it.
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
  
  # NOTE: there is deliberately no environment.persistence."/persist".users
  # block here. The fileSystems entry below bind-mounts the ENTIRE home
  # directory from /persist/home/${username}, so everything under
  # /home/${username} already survives reboots unconditionally — adding
  # per-directory/per-file impermanence entries on top of that is not just
  # redundant, it actively breaks activation: the persistence-mount-file
  # unit for something like .ssh/config always finds a real (non-mount) file
  # already sitting there (because the parent bind mount put it there first)
  # and refuses to clobber it, failing the switch. If you want to exclude
  # something under home from persistence, that has to be done by NOT
  # storing it under /persist/home/${username}, not by fighting this mount.

  # Link home to /persist/home
  fileSystems."/home/${username}" = {
    device = "/persist/home/${username}";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
    depends = [ "/persist" ];
  };
}
