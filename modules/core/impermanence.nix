{ config, inputs, ... }:

{
  # Impermanence configuration
  # Root filesystem is wiped on every boot
  # Only /persist and /nix survive
  
  environment.persistence."/persist" = {
    hideMounts = true;
    
    directories = [
      # System directories that need to persist
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/bluetooth"
      "/etc/NetworkManager/system-connections"
      
      # Machine ID
      "/etc/machine-id"
    ];
    
    files = [
      # SSH host keys
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };
  
  # Create persist directory structure
  systemd.tmpfiles.rules = [
    "d /persist/home 0755 root root -"
    "d /persist/var 0755 root root -"
    "d /persist/var/lib 0755 root root -"
    "d /persist/var/log 0755 root root -"
  ];
  
  # Wipe root on boot
  boot.initrd.postDeviceCommands = ''
    mkdir -p /mnt
    mount -o subvol=@root /dev/mapper/crypted /mnt
    
    # Create a blank snapshot at first boot
    if [ ! -e /mnt/.blank-snapshot ]; then
      echo "Creating blank snapshot..."
      btrfs subvolume delete /mnt || true
      btrfs subvolume create /mnt
      btrfs subvolume snapshot /mnt /mnt/.blank-snapshot
    fi
    
    # Restore from blank snapshot
    echo "Wiping root filesystem..."
    btrfs subvolume delete /mnt
    btrfs subvolume snapshot /mnt/.blank-snapshot /mnt
    
    umount /mnt
  '';
}
