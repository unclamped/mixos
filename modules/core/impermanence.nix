{ config, inputs, pkgs, ... }:

{
  # Impermanence configuration
  # Root filesystem is wiped on every boot
  # Only /persist and /nix survive

  fileSystems."/persist".neededForBoot = true;
  
  environment.persistence."/persist" = {
    hideMounts = true;
    
    directories = [
      # System directories that need to persist
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/bluetooth"
      "/var/lib/docker"
      "/etc/NetworkManager/system-connections"
    ];
    
    files = [
      # Machine ID (must be a file)
      "/etc/machine-id"

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
  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to blank snapshot";
    wantedBy = [ "initrd.target" ];
    # Must run after LUKS is open, before the root fs is mounted
    after = [ "systemd-cryptsetup@crypted.service" ];
    requires = [ "systemd-cryptsetup@crypted.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    unitConfig.OnFailure = "emergency.target";
    serviceConfig.Type = "oneshot";
    serviceConfig.TimeoutStartSec = "1m";
    path = [ pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux pkgs.gnugrep  ];
    script = ''
      # Mount the TOP-LEVEL btrfs volume, not a specific subvolume.
      # This lets us delete and recreate 'root' as a named path.
      mkdir -p /mnt
      mount -t btrfs -o subvol=/ /dev/mapper/crypted /mnt

      if ! btrfs subvolume show /mnt/root-blank >/dev/null 2>&1; then
        btrfs subvolume create /mnt/root-blank-tmp
        btrfs subvolume snapshot -r /mnt/root-blank-tmp /mnt/root-blank
        btrfs subvolume delete /mnt/root-blank-tmp
      fi

      if btrfs subvolume show /mnt/root >/dev/null 2>&1; then
        btrfs subvolume list -o /mnt/root | cut -f9- -d' ' | while read -r sub; do
          btrfs subvolume delete "/mnt/$sub"
        done
        btrfs subvolume delete /mnt/root
      fi

      btrfs subvolume snapshot /mnt/root-blank /mnt/root
      umount /mnt
    '';
  };
}
