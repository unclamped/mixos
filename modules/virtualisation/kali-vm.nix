{ config, pkgs, lib, username, ... }:

# ─── Kali Linux as a declarative libvirt guest ──────────────────────────────
#
# Why a VM at all, given nixpkgs has most of the tools?
#
# nixpkgs genuinely covers the overwhelming majority of what Kali ships:
# nmap, metasploit, burpsuite, wireshark, sqlmap, hashcat, john, aircrack-ng,
# hydra, gobuster/ffuf, bettercap, responder, impacket, bloodhound, radare2,
# ghidra, volatility3, binwalk, and so on. What you do NOT get outside Kali is:
#
#   * the kali-tools-* metapackages and the curated menu structure — i.e. the
#     "everything is already there and already on PATH" experience;
#   * a handful of Offensive-Security in-house or Kali-patched tools
#     (kali-tweaks, kali-undercover, the Kali-patched aircrack/reaver forks,
#     some wordlist/exploit packaging);
#   * Kali-specific kernel patches for wireless injection on some chipsets;
#   * an environment that courseware and write-ups assume verbatim.
#
# So: cerf gets the native tools for day-to-day work (fast, no VM overhead —
# see hosts/cerf/pentest.nix), and this VM exists for the cases where you
# actually want *Kali*.
#
# ── How this is declarative ─────────────────────────────────────────────────
#
# The DOMAIN — CPU topology, RAM, disks, NIC, graphics, firmware — is generated
# from the options below and `virsh define`d on every boot, so editing this
# file and rebuilding changes the VM. Anything clicked in virt-manager is
# overwritten.
#
# The IMAGE is Kali's official prebuilt QEMU disk, pinned by SHA-256. It is
# downloaded to /persist on first boot rather than into the Nix store on
# purpose: it is a ~3.9 GiB archive expanding to a much larger qcow2, and
# putting that in the store on a laptop costs disk twice over for no
# reproducibility gain the pinned hash does not already provide. Swap
# `imageUrl`/`imageSha256` and delete the disk to move to a newer release.
#
# The guest's own disk is a thin qcow2 OVERLAY on top of that pristine image,
# so "reset the VM to factory" is: delete the overlay and reboot.

let
  cfg = config.kaliVm;

  # Absolute paths, all under /persist because root is wiped on every boot.
  baseDir  = "/persist/var/lib/libvirt/kali";
  archive  = "${baseDir}/${cfg.imageName}.7z";
  baseImg  = "${baseDir}/${cfg.imageName}.qcow2";
  overlay  = "${baseDir}/${cfg.name}-overlay.qcow2";
  nvram    = "${baseDir}/${cfg.name}-vars.fd";

  # ── Two domain flavours, because KVM may not be available ────────────────
  #
  # `virsh define` of a type='kvm' domain is rejected outright when the
  # emulator has no KVM support:
  #     unsupported configuration: Emulator '.../qemu-system-x86_64'
  #     does not support virt type 'kvm'
  # and, more confusingly, when the machine type is the alias `q35` libvirt
  # cannot canonicalise it without KVM capabilities, so the failure surfaces
  # instead as the misleading
  #     operation failed: Unable to find 'efi' firmware that is compatible
  #     with the current configuration
  # even though the firmware descriptors are perfectly fine. Both were
  # observed on cerf; see the KVM check in the setup script below for the
  # actual cause and the fix.
  #
  # So: build both, and let the script pick at runtime. TCG needs a different
  # CPU model too — host-passthrough is meaningless without hardware virt.
  domainXmlFor = accel: pkgs.writeText "${cfg.name}-domain-${accel}.xml" ''
    <domain type='${accel}'>
      <name>${cfg.name}</name>
      <title>Kali Linux</title>
      <memory unit='MiB'>${toString cfg.memoryMiB}</memory>
      <currentMemory unit='MiB'>${toString cfg.memoryMiB}</currentMemory>
      <vcpu placement='static'>${toString cfg.vcpus}</vcpu>
      <!-- firmware='efi' lets libvirt choose from the OVMF descriptors QEMU
           registers, rather than hardcoding a store path that changes on
           every nixpkgs bump. libvirt creates the variable store itself from
           the matching template on first start. -->
      <os firmware='efi'>
        <type arch='x86_64' machine='q35'>hvm</type>
        <nvram>${nvram}</nvram>
        <boot dev='hd'/>
      </os>
      <features>
        <acpi/>
        <apic/>
        <vmport state='off'/>
      </features>
      ${if accel == "kvm" then ''
        <!-- host-passthrough so the guest sees AES-NI etc. rather than a
             lowest-common-denominator CPU; this VM never migrates anywhere. -->
        <cpu mode='host-passthrough' check='none' migratable='off'/>
      '' else ''
        <!-- TCG: there is no host CPU to pass through. "maximum" gives the
             guest every feature this QEMU can emulate. -->
        <cpu mode='maximum'/>
      ''}
      <clock offset='utc'>
        <timer name='rtc' tickpolicy='catchup'/>
        <timer name='pit' tickpolicy='delay'/>
        <timer name='hpet' present='no'/>
      </clock>
      <on_poweroff>destroy</on_poweroff>
      <on_reboot>restart</on_reboot>
      <on_crash>destroy</on_crash>
      <pm>
        <suspend-to-mem enabled='no'/>
        <suspend-to-disk enabled='no'/>
      </pm>
      <devices>
        <emulator>${pkgs.qemu_kvm}/bin/qemu-system-x86_64</emulator>

        <disk type='file' device='disk'>
          <driver name='qemu' type='qcow2' discard='unmap' cache='none' io='native'/>
          <source file='${overlay}'/>
          <target dev='vda' bus='virtio'/>
        </disk>

        <controller type='usb' index='0' model='qemu-xhci' ports='15'/>
        <controller type='pci' index='0' model='pcie-root'/>

        <interface type='network'>
          <source network='default'/>
          <model type='virtio'/>
        </interface>

        <console type='pty'>
          <target type='serial' port='0'/>
        </console>

        <channel type='spicevmc'>
          <target type='virtio' name='com.redhat.spice.0'/>
        </channel>
        <!-- guest agent: lets virsh shutdown/freeze work properly -->
        <channel type='unix'>
          <target type='virtio' name='org.qemu.guest_agent.0'/>
        </channel>

        <input type='tablet' bus='usb'/>
        <input type='mouse' bus='ps2'/>
        <input type='keyboard' bus='ps2'/>

        <graphics type='spice' autoport='yes' listen='127.0.0.1'>
          <listen type='address' address='127.0.0.1'/>
          <image compression='off'/>
          <gl enable='no'/>
        </graphics>
        <!-- virtio-gpu, not qxl: qxl is legacy and its Wayland/SPICE path on
             an old iGPU host is worse than plain virtio. -->
        <video>
          <model type='virtio' heads='1' primary='yes'>
            <acceleration accel3d='no'/>
          </model>
        </video>

        <redirdev bus='usb' type='spicevmc'/>
        <redirdev bus='usb' type='spicevmc'/>

        <!-- Entropy: without this the guest blocks on /dev/random during
             key generation, which for a pentest box is constant. -->
        <rng model='virtio'>
          <backend model='random'>/dev/urandom</backend>
        </rng>

        <memballoon model='virtio'/>
      </devices>
    </domain>
  '';

  setupScript = pkgs.writeShellApplication {
    name = "kali-vm-setup";
    runtimeInputs = with pkgs; [ coreutils curl p7zip qemu_kvm libvirt gnused ];
    text = ''
      set -euo pipefail

      mkdir -p "${baseDir}"

      # ── 1. the pristine base image, hash-pinned ────────────────────────────
      if [ ! -f "${baseImg}" ]; then
        if [ ! -f "${archive}" ]; then
          echo "kali-vm: downloading ${cfg.imageName} (~3.9 GiB), this happens once..."
          curl --fail --location --retry 3 --continue-at - \
               --output "${archive}.part" "${cfg.imageUrl}"
          mv "${archive}.part" "${archive}"
        fi

        echo "kali-vm: verifying checksum..."
        echo "${cfg.imageSha256}  ${archive}" | sha256sum --check --status || {
          echo "kali-vm: CHECKSUM MISMATCH — refusing to use the download." >&2
          echo "kali-vm: delete ${archive} and retry, or update imageSha256." >&2
          exit 1
        }

        echo "kali-vm: extracting..."
        7z x -y -o"${baseDir}" "${archive}" >/dev/null
        # The archive lays the disk out under a directory named after the
        # image; normalise wherever it landed to the path the domain expects.
        found=$(find "${baseDir}" -name '*.qcow2' ! -name '*-overlay.qcow2' -print -quit)
        if [ -z "$found" ]; then
          echo "kali-vm: no qcow2 found in the archive" >&2
          exit 1
        fi
        [ "$found" = "${baseImg}" ] || mv "$found" "${baseImg}"
        chmod 0444 "${baseImg}"

        # The archive is only needed to produce the image.
        rm -f "${archive}"
      fi

      # ── 2. a thin, resizable overlay the guest actually writes to ──────────
      if [ ! -f "${overlay}" ]; then
        echo "kali-vm: creating overlay disk (${toString cfg.diskGiB}G virtual)"
        qemu-img create -f qcow2 \
          -b "${baseImg}" -F qcow2 \
          "${overlay}" "${toString cfg.diskGiB}G"
      fi

      # (No step 3: libvirt creates the UEFI variable store at ${nvram} from
      # the firmware descriptor it selects, so nothing to seed here.)

      chown -R ${username}:users "${baseDir}"

      # ── 4. the libvirt NAT network the domain's NIC attaches to ────────────
      # NixOS defines `default` but leaves it inactive and non-autostarting, so
      # `virsh start kali` would fail with "Network not found / not active".
      virsh net-autostart default >/dev/null 2>&1 || true
      virsh net-info default 2>/dev/null | grep -q 'Active:.*yes' || \
        virsh net-start default >/dev/null 2>&1 || true

      # ── 5. pick the domain flavour ──────────────────────────────────────────
      # Which flavour depends on whether this machine can actually do hardware
      # virtualisation right now. On the EliteBook it could not, because
      # Intel VT-x ships DISABLED in HP's firmware: /proc/cpuinfo had no `vmx`
      # flag at all and /dev/kvm did not exist. That is a BIOS setting, not
      # something the OS can turn on:
      #     F10 at boot -> Security -> System Security
      #                 -> Virtualization Technology (VTx)   = Enable
      #                 -> (VTd too, if you ever want PCI passthrough)
      # Once that is on, the next boot re-runs this service and silently
      # upgrades the definition to KVM.
      if [ -e /dev/kvm ]; then
        domainXml=${domainXmlFor "kvm"}
      else
        cat >&2 <<'WARN'

        ############################################################
        #  KVM IS NOT AVAILABLE — the Kali guest will run under TCG #
        #  emulation, which on this CPU is unusably slow.           #
        #                                                           #
        #  /dev/kvm is missing. Check for hardware virtualisation:  #
        #      grep -c vmx /proc/cpuinfo     # 0 means it is off    #
        #                                                           #
        #  Enable it in firmware (HP EliteBook: F10 at boot):       #
        #      Security -> System Security                          #
        #              -> Virtualization Technology (VTx) = Enable  #
        #                                                           #
        #  Then reboot. This service picks KVM up automatically.    #
        ############################################################

WARN
        domainXml=${domainXmlFor "qemu"}
      fi

      # ── 6. define (or redefine) the domain from this config ────────────────
      # `virsh define` fails if the domain already exists, so make the
      # declaration idempotent by undefining first when needed (unless it's
      # currently running, in which case the live definition is left alone).
      if virsh dominfo ${cfg.name} >/dev/null 2>&1; then
        state="$(virsh domstate ${cfg.name} 2>/dev/null || true)"
        case "$state" in
          running|paused|pmsuspended|in\ shutdown)
            echo "kali-vm: domain ${cfg.name} is active ($state); keeping current definition."
            ;;
          *)
            virsh undefine ${cfg.name} --nvram >/dev/null 2>&1 || virsh undefine ${cfg.name}
            rm -f "${nvram}"
            virsh define "$domainXml"
            ;;
        esac
      else
        virsh define "$domainXml"
      fi

      ${lib.optionalString cfg.autostart "virsh autostart ${cfg.name}"}
      ${lib.optionalString (!cfg.autostart) "virsh autostart --disable ${cfg.name} || true"}
    '';
  };
in
{
  options.kaliVm = {
    enable = lib.mkEnableOption "the declarative Kali Linux libvirt guest";

    name = lib.mkOption { type = lib.types.str; default = "kali"; description = "libvirt domain name."; };
    memoryMiB = lib.mkOption { type = lib.types.int; default = 6144; description = "Guest RAM."; };
    vcpus = lib.mkOption { type = lib.types.int; default = 4; description = "Guest vCPUs."; };
    diskGiB = lib.mkOption { type = lib.types.int; default = 80; description = "Virtual size of the overlay disk (thin: it only uses what it writes)."; };
    autostart = lib.mkOption { type = lib.types.bool; default = false; description = "Start the guest at boot. Off by default — it is a laptop."; };

    imageName = lib.mkOption {
      type = lib.types.str;
      default = "kali-linux-2026.2-qemu-amd64";
      description = "Base name of Kali's prebuilt QEMU image.";
    };
    imageUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://cdimage.kali.org/kali-2026.2/kali-linux-2026.2-qemu-amd64.7z";
      description = "Where to fetch the prebuilt QEMU image from.";
    };
    imageSha256 = lib.mkOption {
      type = lib.types.str;
      default = "c7c35588d05277c482c908bf7a136d348f76ffa68700b04ff53c0b217e6bd071";
      description = ''
        SHA-256 of the archive, from https://cdimage.kali.org/current/SHA256SUMS.
        A mismatch aborts rather than booting an unverified disk.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # libvirt's NAT network, which the domain's <interface network='default'/>
    # refers to. Without this the guest has no NIC and virsh start fails.
    virtualisation.libvirtd.allowedBridges = [ "virbr0" ];

    systemd.services."kali-vm-setup" = {
      description = "Provision and define the Kali libvirt guest";
      after = [ "libvirtd.service" "network-online.target" "persist.mount" ];
      wants = [ "libvirtd.service" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe setupScript;
        # The first run downloads ~3.9 GiB; don't let systemd time it out.
        TimeoutStartSec = "infinity";
      };
    };

    # Convenience wrappers, so this is `kali` from any terminal rather than a
    # virsh incantation.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "kali" ''
        set -eu
        case "''${1:-start}" in
          start)   [ -e /dev/kvm ] || echo "warning: no /dev/kvm — running under TCG emulation. Enable VT-x in the BIOS (F10 -> Security -> System Security)." >&2
                   virsh --connect qemu:///system net-start default >/dev/null 2>&1 || true
                   virsh --connect qemu:///system start ${cfg.name} 2>/dev/null || true
                   exec virt-viewer --connect qemu:///system --attach ${cfg.name} ;;
          stop)    exec virsh --connect qemu:///system shutdown ${cfg.name} ;;
          kill)    exec virsh --connect qemu:///system destroy ${cfg.name} ;;
          status)  exec virsh --connect qemu:///system dominfo ${cfg.name} ;;
          reset)   echo "This deletes all changes made inside the VM."
                   printf 'type RESET to confirm: '; read -r a
                   [ "$a" = RESET ] || exit 1
                   virsh --connect qemu:///system destroy ${cfg.name} 2>/dev/null || true
                   sudo rm -f ${overlay}
                   sudo systemctl restart kali-vm-setup
                   echo "overlay recreated; the VM is back to the shipped image." ;;
          *)       echo "usage: kali [start|stop|kill|status|reset]" >&2; exit 2 ;;
        esac
      '')
    ];
  };
}
