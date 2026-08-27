# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Rebuild and switch to new configuration (pick the host you are ON)
sudo nixos-rebuild switch --flake ~/mixos#turing   # the desktop
sudo nixos-rebuild switch --flake ~/mixos#cerf     # the EliteBook 840 G2

# Dry-run build (check for errors without switching)
sudo nixos-rebuild dry-build --flake ~/mixos#turing

# Evaluate a host without building anything (fastest syntax/option check)
nix eval .#nixosConfigurations.cerf.config.system.build.toplevel.drvPath

# Update all flake inputs
nix flake update

# Update a single input
nix flake lock --update-input <input-name>

# Enter the dev shell (provides age, ragenix, nixpkgs-fmt)
nix develop

# Format nix files
nixpkgs-fmt <file>

# Garbage collect generations older than 7 days
sudo nix-collect-garbage --delete-older-than 7d

# Create a BTRFS snapshot before a risky change
sudo btrfs subvolume snapshot / /.snapshots/$(date +%Y%m%d-%H%M%S)
```

## Git workflow

All changes must be committed and merged to `main` without prompting. When work is done in a worktree:

1. `git add` the changed files and `git commit` with a descriptive message.
2. Rebase the worktree branch onto `main` (resolve any conflicts), then fast-forward merge into `main`.
3. Remove the worktree and delete the branch once merged.

Do this automatically at the end of every task — do not wait to be asked.

## Architecture

A **two-host** NixOS flake: `turing` (desktop — NVIDIA, three monitors, gaming/VR)
and `cerf` (HP EliteBook 840 G2 — CCNAv7 / cybersec laptop). The username is
`maru` and is threaded through the entire config via `specialArgs`.

**The cardinal rule of this repo: never fork a module per host.** If two hosts
need to differ, the shared module grows an *option* and each host sets it. The
repo previously had `home/default.nix` (turing) beside `home/cerf.nix`, and
`hyprlain.nix` beside `hyprlain-laptop.nix` — near-identical copies that had
already silently drifted (different stateVersion, one had the D-Bus portal fix
and the other didn't, a DPMS bug fixed in neither). That layout is gone; don't
recreate it.

**Flake inputs of note:**
- `nixpkgs` → `nixos-unstable`
- `home-manager` — user environment, follows nixpkgs
- `impermanence` — root-wipe-on-boot setup
- `disko` — declarative disk partitioning (LUKS2 → BTRFS)
- `stylix` — base16 theming (the Lain "Wired" palette, `hosts/*/lain-base16.yaml`)
- `ragenix` — age-encrypted secrets
- `hyprland` — Wayland compositor (pinned to its own upstream, not nixpkgs)
- `nix-cachyos-kernel` — provides `pkgs.cachyosKernels`; turing only
- `vicinae` — do **not** add `inputs.nixpkgs.follows` to it (avoids cachix cache misses)
- `nixcord` — Vencord/Equicord Discord client via HM module
- `ida-src` — an absolute `path:` input to the gitignored `ida/` directory. It is
  only *forced* when something references `pkgs.ida-pro`, so a machine without it
  can still evaluate the flake; both hosts install IDA, so both need the directory.

### Module layout

| Path | Purpose |
|------|---------|
| `flake.nix` | Inputs, outputs, `nixosConfigurations.{turing,cerf}`, `commonModules`, `hmFor` |
| `hosts/<host>/default.nix` | Host-level config: hostname, locale, Stylix, kernel, packages |
| `hosts/<host>/disko.nix` | Disk layout |
| `hosts/<host>/hardware.nix` | Generated hardware config |
| `hosts/cerf/pentest.nix` | The native (non-VM) security toolkit |
| `modules/core/` | boot, impermanence, networking, users, `fhs.nix` (nix-ld + FHS shell, **cerf only**) |
| `modules/desktop/` | Hyprland enablement, SDDM, plymouth, `power-menu.nix` |
| `modules/hardware/` | nvidia, fido2, power-saving, `laptop-keys.nix`, `intel-gen8-kitty.nix` |
| `modules/services/` | pipewire, docker, `syncthing.nix` |
| `modules/virtualisation/` | `libvirt.nix`, `kali-vm.nix` (declarative Kali guest) |
| `home/default.nix` | **Shared** HM base — imported by both host profiles |
| `home/hosts/<host>/` | Per-host HM profile + that host's Hyprlain settings |
| `home/modules/desktop/hyprlain/` | The Hyprlain session, as ONE parameterised module |
| `home/modules/` | Per-app HM configs: zsh, kitty, browsers, waybar, rofi, vicinae, neovim |

### The Hyprlain session

`home/modules/desktop/hyprlain/default.nix` defines an `options.hyprlain` tree
and generates every session file from it: `hyprland.lua`, the session-scoped
kitty/dunst/hypridle/hyprlock configs, the waybar config + stylesheet, and the
wlogout layout + stylesheet. Hosts set options in
`home/hosts/<host>/hyprlain-*.nix` and add nothing else.

**Two things about this Hyprland that bite repeatedly:**

1. It runs a **Lua** config, so `hyprctl dispatch <x>` evaluates `<x>` as Lua
   (`return hl.dispatch(<x>)`), *not* as a native dispatcher. `hyprctl dispatch
   dpms on` is a syntax error, not a dispatch. Pass Lua: `hyprctl dispatch
   "hl.dsp.dpms({on=true})"`.
2. Dispatchers validate their argument as a **table**. `hl.dsp.dpms('on')`
   returns `ok` and does nothing. Always pass `{...}`.

Validate generated Lua with `luac -p` on the rendered file, or
`Hyprland --verify-config`.

### Impermanence model

Root (`/`) is wiped to a blank BTRFS snapshot on every boot via an initrd systemd service. Only two subvolumes survive reboots:
- `/nix` — the nix store
- `/persist` — explicitly opt-in persistent state

The user's home (`/home/maru`) is bind-mounted **wholesale** from `/persist/home/maru` via a `fileSystems."/home/maru"` entry in `modules/core/users.nix` — everything under `/home/maru` survives reboots unconditionally, with no per-directory/per-file opt-in needed. Do **not** add entries for paths under `/home/maru` to `environment.persistence."/persist".users.maru.{directories,files}` — that pattern conflicts with the wholesale bind mount (the target file/dir already exists by the time the persistence unit runs, so it refuses to clobber it and the switch fails). System-level (non-home) paths like `/etc/machine-id` or `/var/lib/docker` still use the normal `environment.persistence."/persist".directories`/`.files` opt-in lists — see `modules/core/impermanence.nix`.

**When adding new apps that need persistent state**, no action is needed if their config lives under `~/.config`, `~/.local/share`, etc. — it already persists via the home bind mount. Only system-level state outside `/home/maru` needs an explicit entry.

### Theming

Stylix is configured per host (`hosts/<host>/default.nix`) and both hosts use
the same base16 scheme — the Lain "Wired" palette in `hosts/<host>/lain-base16.yaml`
— so the two machines read as one system. Both `stylix.image` and
`stylix.base16Scheme` are set; `base16Scheme` takes precedence for colors, and
the image is still used as the wallpaper source where applicable. Apps with
bespoke Hyprlain theming (spicetify, vicinae, nixcord, GTK/Qt) have their Stylix
targets disabled so the hand-written theme wins.

### Secrets

Secrets are managed with ragenix. Age keys live at `~/.config/age/keys.txt` (must be present on the machine; persisted via `~/.config` in the persistence list). Secret declarations go in `secrets/secrets.nix`; encrypted files are `.age` files in `secrets/`. Reference in config via `config.age.secrets.<name>.path`.
