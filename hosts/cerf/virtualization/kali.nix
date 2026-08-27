{ config, pkgs, lib, ... }:

let
  vmName = "kali";
  vmDir = "/persist/var/lib/libvirt/images";
  vmDisk = "${vmDir}/${vmName}.qcow2";
  vmRamMiB = 8192;
  vmVcpus = 4;
  vmDiskGiB = 120;

  # Place the Kali installer ISO at this path.
  kaliIso = "/persist/isos/kali-linux-2026.2-installer-amd64.iso";
in
{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.maru.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    qemu_kvm
    virt-manager
    virt-viewer
  ];

  systemd.tmpfiles.rules = [
    "d ${vmDir} 0755 root root -"
    "d /persist/isos 0755 root root -"
  ];

  systemd.services."libvirt-define-${vmName}" = {
    description = "Define ${vmName} VM in libvirt if missing";
    after = [ "libvirtd.service" ];
    wants = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ libvirt qemu_kvm coreutils ];
    script = ''
      set -euo pipefail

      mkdir -p ${vmDir}

      if [ ! -f "${vmDisk}" ]; then
        qemu-img create -f qcow2 "${vmDisk}" ${toString vmDiskGiB}G
      fi

      if ! virsh dominfo ${vmName} >/dev/null 2>&1; then
        virt-install \
          --name ${vmName} \
          --memory ${toString vmRamMiB} \
          --vcpus ${toString vmVcpus} \
          --cpu host-passthrough \
          --os-variant kali-rolling \
          --disk path=${vmDisk},format=qcow2,bus=virtio \
          --cdrom ${kaliIso} \
          --network network=default,model=virtio \
          --graphics spice \
          --video qxl \
          --channel spicevmc \
          --boot uefi \
          --noautoconsole
      fi

      virsh autostart ${vmName} || true
    '';
  };
}
