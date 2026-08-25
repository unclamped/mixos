{ ... }:

{
  disko.devices = {
    disk = {
      cerf-nixos = {
        type = "disk";

        # IMPORTANT — this is NOT the whole disk. It is the single partition
        # you create by hand inside the pre-existing trailing free space on
        # the Windows GPT disk (see the install steps discussed in chat / the
        # host README). disko formats *only* this one block device — it never
        # touches /dev/sda's partition table, so the ESP, MSR, and Windows
        # NTFS partition are completely untouched, and the NixOS partition
        # stays deletable later to extend Windows back into the space.
        #
        # Confirmed on the real hardware via lsblk: parted assigned this as
        # partition 5, not 4 (there was presumably a pre-existing partition
        # 4, e.g. a recovery partition, ahead of the trailing free space).
        device = "/dev/disk/by-partuuid/4db19d53-3692-42c0-a0b0-cbf51a303c2f";

        content = {
          type = "luks";
          # Matches modules/core/impermanence.nix's rollback service, which
          # hardcodes systemd-cryptsetup@crypted.service and
          # /dev/mapper/crypted. Keep this name if you reuse that module.
          name = "crypted";
          settings = {
            allowDiscards = true;
            bypassWorkqueues = true; # perf improvement for SSDs
          };
          # LUKS passphrase is set interactively by disko during installation.

          content = {
            type = "btrfs";
            extraArgs = [ "-f" "-L" "cerf-nixos" ];

            subvolumes = {
              # Root — wiped on every boot (impermanence)
              "/root" = {
                mountpoint = "/";
                mountOptions = [ "compress=zstd" "noatime" ];
              };

              # Nix store — persistent
              "/nix" = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd" "noatime" ];
              };

              # Persistent data
              "/persist" = {
                mountpoint = "/persist";
                mountOptions = [ "compress=zstd" "noatime" ];
              };

              # Swap — swapFILE inside btrfs, deliberately NOT a separate
              # partition, so the disk keeps exactly one new partition (see
              # the note at the top of this file). 8G is plenty on 16G RAM.
              "/swap" = {
                mountpoint = "/swap";
                swap.swapfile.size = "8G";
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
}
