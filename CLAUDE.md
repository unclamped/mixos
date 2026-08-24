# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Rebuild and switch to new configuration
sudo nixos-rebuild switch --flake ~/mixos#turing

# Dry-run build (check for errors without switching)
sudo nixos-rebuild dry-build --flake ~/mixos#turing

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

This is a single-host NixOS flake for the host `turing`. The username is `maru` and is threaded through the entire config via `specialArgs`.

**Flake inputs of note:**
- `nixpkgs` → `nixos-unstable`
- `home-manager` — user environment, follows nixpkgs
- `impermanence` — root-wipe-on-boot setup
- `disko` — declarative disk partitioning (LUKS2 → BTRFS)
- `stylix` — base16 theming from a single wallpaper/scheme
- `ragenix` — age-encrypted secrets
- `hyprland` — Wayland compositor (pinned to its own upstream, not nixpkgs)
- `nix-cachyos-kernel` — provides `pkgs.cachyosKernels`; loaded via overlay
- `vicinae` — do **not** add `inputs.nixpkgs.follows` to it (avoids cachix cache misses)
- `nixcord` — Vencord/Equicord Discord client via HM module

### Module layout

| Path | Purpose |
|------|---------|
| `flake.nix` | Inputs, outputs, `nixosConfigurations.turing` |
| `hosts/turing/default.nix` | Host-level config: hostname, locale, Stylix theme, kernel, system packages |
| `hosts/turing/disko.nix` | Disk layout: GPT → ESP + LUKS2 → BTRFS subvolumes |
| `hosts/turing/hardware.nix` | Generated hardware config |
| `modules/core/` | boot, impermanence, networking, users |
| `modules/desktop/hyprland.nix` | System-level Hyprland enablement |
| `modules/hardware/nvidia.nix` | NVIDIA proprietary driver + Wayland env vars |
| `modules/services/pipewire.nix` | Audio |
| `home/default.nix` | Home Manager root: user packages, git, nixcord |
| `home/modules/` | Per-app HM configs: zsh, kitty, librewolf, hyprland (user), waybar, rofi, vicinae, neovim |

### Impermanence model

Root (`/`) is wiped to a blank BTRFS snapshot on every boot via an initrd systemd service. Only two subvolumes survive reboots:
- `/nix` — the nix store
- `/persist` — explicitly opt-in persistent state

The user's home (`/home/maru`) is bind-mounted from `/persist/home/maru`. Directories like `~/.config`, `~/.local/share`, `~/.cache`, `.ssh`, and `Projects` are listed in `modules/core/users.nix` under `environment.persistence."/persist".users.maru.directories` — anything not listed there is lost on reboot.

**When adding new apps that need persistent state**, add their config/data directories to that list in `modules/core/users.nix`.

### Theming

Stylix is configured in `hosts/turing/default.nix`. It applies a base16 scheme (`gruvbox-dark`) system-wide. Both `stylix.image` and `stylix.base16Scheme` are set — `base16Scheme` takes precedence for colors; the image is still used as the wallpaper source where applicable.

### Secrets

Secrets are managed with ragenix. Age keys live at `~/.config/age/keys.txt` (must be present on the machine; persisted via `~/.config` in the persistence list). Secret declarations go in `secrets/secrets.nix`; encrypted files are `.age` files in `secrets/`. Reference in config via `config.age.secrets.<name>.path`.
