{ config, pkgs, lib, username, ... }:

# ─── Keeping turing and cerf in sync ────────────────────────────────────────
#
# The workflow this exists for: work on cerf at university, come home, and pick
# up on turing without thinking about it. That rules out anything manual (rsync
# by hand, git for notes) and anything cloud-hosted (these are the same
# person's two machines on the same LAN most evenings).
#
# Syncthing is the right tool here: peer-to-peer, no server, continuous, and it
# syncs over the LAN at full speed when both machines are on it while still
# working over the internet when cerf is away.
#
# ── Topology ───────────────────────────────────────────────────────────────
#
# Two laptops/desktops alone means a change only propagates while BOTH are
# powered on at the same time — leave cerf at university with unsaved work and
# turing sees nothing until cerf comes back. The Debian 13 box at home fixes
# that: add it as a third peer and it acts as an always-on hub. cerf pushes to
# it from campus, turing pulls from it whenever it wakes up, and neither has to
# be online at the same moment as the other.
#
# On the Debian side that is just:
#     sudo apt install syncthing
#     sudo systemctl enable --now syncthing@<user>
#     syncthing cli show system | grep myID     # its device ID
# then accept the same folder IDs ("Notes", "Documents", "Projects") there and
# point them at wherever you want them stored. Nothing about the Debian host
# needs to be in this repo — it is a peer, not a server, and Syncthing has no
# concept of a master.
#
# ── One-time setup, ONCE, after the first rebuild on both machines ──────────
#
# Device IDs are generated on first start and are not secrets, but they are not
# known until then. Get each one with:
#
#     syncthing --device-id            # run on each machine
#     # or: http://127.0.0.1:8384 -> Actions -> Show ID
#
# then put them in `syncthing.peers` below (hosts/*/default.nix) and rebuild
# both. After that everything -- which folders exist, where they live, who they
# are shared with -- is declarative, and `overrideFolders`/`overrideDevices`
# means the config here always wins over anything clicked in the web UI.
#
# The web UI is at http://127.0.0.1:8384 on each machine, bound to loopback.

let
  cfg = config.syncthing;
in
{
  options.syncthing = {
    thisDevice = lib.mkOption {
      type = lib.types.str;
      description = "This host's name as it appears to the other peers.";
    };

    peers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        cerf = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
        debian = "YYYYYYY-YYYYYYY-YYYYYYY-YYYYYYY-YYYYYYY-YYYYYYY-YYYYYYY-YYYYYYY";
      };
      description = ''
        Other machines to sync with: name → Syncthing device ID. Fill in after
        running `syncthing --device-id` on each. An empty set means Syncthing
        runs but shares nothing, which is the safe pre-setup state.
      '';
    };

    folders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "Notes"     = "/home/${username}/Notes";      # Obsidian vault
        "Documents" = "/home/${username}/Documents";
        "Projects"  = "/home/${username}/Projects";
      };
      description = "Folder label → path. Every folder is shared with every peer.";
    };
  };

  config = {
    services.syncthing = {
      enable = true;
      user = username;
      group = "users";
      dataDir = "/home/${username}";
      configDir = "/home/${username}/.config/syncthing";

      # Loopback only. These machines reach each other through Syncthing's own
      # (authenticated, encrypted) protocol on 22000; the admin UI has no
      # business being on the network.
      guiAddress = "127.0.0.1:8384";

      # The declarations below are the source of truth: anything added or
      # changed in the web UI is reverted on the next rebuild. That is the
      # point — it is what stops the two machines from drifting.
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = lib.mapAttrs (_name: id: { inherit id; }) cfg.peers;

        folders = lib.mapAttrs
          (_label: path: {
            inherit path;
            devices = lib.attrNames cfg.peers;
            # Keep a month of deleted/overwritten versions. Coming back from
            # university and finding a conflict resolved the wrong way is
            # exactly the failure this protects against.
            versioning = {
              type = "simple";
              params.keep = "10";
            };
          })
          cfg.folders;

        options = {
          # LAN discovery so the two find each other at home without relaying.
          localAnnounceEnabled = true;
          # ...and global discovery + relays so cerf still syncs from campus.
          globalAnnounceEnabled = true;
          relaysEnabled = true;
          urAccepted = -1;    # no usage reporting
        };
      };
    };

    # Syncthing's sync protocol (22000 TCP/UDP) and LAN discovery (21027 UDP).
    # The GUI port is deliberately NOT opened.
    networking.firewall = {
      allowedTCPPorts = [ 22000 ];
      allowedUDPPorts = [ 22000 21027 ];
    };

    environment.systemPackages = [ pkgs.syncthing ];

    # The sync roots must exist and be owned by the user before Syncthing
    # starts, otherwise it creates them as root or refuses the folder.
    systemd.tmpfiles.rules =
      lib.mapAttrsToList (_label: path: "d ${path} 0755 ${username} users -") cfg.folders;
  };
}
