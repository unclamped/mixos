{ ... }:

{
  disko.devices = {
    disk = {
      turing = {
        type = "disk";
        device = "/dev/sdb";  # CHANGE THIS to your secondary SSD (e.g., /dev/nvme1n1 or /dev/sdb)
        content = {
          type = "gpt";
          partitions = {
            # ESP partition for systemd-boot
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" "umask=0077" ];
              };
            };
            
            # Encrypted BTRFS partition
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                settings = {
                  allowDiscards = true;
                  bypassWorkqueues = true;  # Performance improvement for SSDs
                };
                # Password will be set during installation
                
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-L" "nixos" ];
                  
                  subvolumes = {
                    # Root - wiped on every boot (impermanence)
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    
                    # Nix store - persistent
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    
                    # Persistent data
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    
                    # Swap
                    "/swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "16G";  # Adjust based on your RAM
                    };
                    
                    # Snapshots storage
                    "/snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
  
  # Note: This will be created automatically by disko
  # The snapshots subvolume will store BTRFS snapshots for rollbacks
}
