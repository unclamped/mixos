{ config, pkgs, lib, username, ... }:

# libvirt/QEMU host setup. Kept separate from any particular VM definition so
# a second guest (a Windows lab box, a NixOS test VM) is just another file.

{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;          # TPM 2.0 for guests that insist on one
      # NOTE: there is deliberately no `ovmf` block here. That submodule was
      # removed upstream — every OVMF image QEMU ships is registered with
      # libvirt by default now, so guests just ask for <os firmware='efi'>
      # and libvirt picks a matching firmware descriptor.
    };
    onBoot = "ignore";              # don't auto-resume guests on every boot
    onShutdown = "shutdown";        # ...but shut them down cleanly on halt
  };

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.${username}.extraGroups = [ "libvirtd" "kvm" ];

  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice-gtk
    virtio-win     # virtio driver ISO, for Windows guests
    libguestfs     # virt-cat / virt-edit / guestmount, handy for forensics
  ];

  # libvirt keeps VM definitions, NVRAM and disk images here. Root is wiped on
  # every boot (modules/core/impermanence.nix), so this has to be an explicit
  # persistence entry or every VM vanishes at reboot.
  environment.persistence."/persist".directories = [
    "/var/lib/libvirt"
  ];
}
