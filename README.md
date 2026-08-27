# NixOS Configuration

A modular, reproducible NixOS configuration with Hyprland, impermanence, and full-disk encryption.

## Features

- 🚀 **Lix**: Enhanced Nix implementation with better error messages
- 🏠 **Home Manager**: Declarative user environment management
- 🗑️ **Impermanence**: Root filesystem wiped on every boot
- 🔒 **Full-disk encryption**: LUKS2 encryption on BTRFS
- 🎨 **Stylix**: Automatic theming from a single wallpaper
- 🪟 **Hyprland**: Modern Wayland compositor
- 🔐 **ragenix**: Age-based secrets management
- 📦 **Modular structure**: Each component is a separate module

## Hosts

| Host | Machine | Notes |
|------|---------|-------|
| `turing` | ASUS desktop, NVIDIA GTX 1660 SUPER | three monitors, gaming, VR, music, reverse engineering |
| `cerf` | HP EliteBook 840 G2 (i5-5300U, HD 5500) | CCNAv7 / cybersec laptop, dual-boots Windows |

Both share almost everything. Where they differ, the shared module takes an
**option** and the host sets it — there are deliberately no per-host copies of
a module in this repo.

## Structure

```
.
├── flake.nix                       # inputs, both nixosConfigurations, commonModules, hmFor
├── hosts/
│   ├── turing/                     # desktop: default.nix, disko.nix, hardware.nix
│   └── cerf/                       # laptop: + boot.nix, pentest.nix
├── modules/                        # SYSTEM modules, shared unless noted
│   ├── core/                       # boot, impermanence, networking, users, fhs (nix-ld; cerf only)
│   ├── services/                   # pipewire, docker, syncthing
│   ├── desktop/                    # hyprland, sddm, plymouth, power-menu
│   ├── hardware/                   # nvidia, fido2, power-saving, laptop-keys, intel-gen8-kitty
│   └── virtualisation/             # libvirt + the declarative Kali guest
├── home/                           # HOME MANAGER
│   ├── default.nix                 # the shared base, imported by both hosts
│   ├── hosts/{turing,cerf}/        # per-host profile + that host's Hyprlain settings
│   └── modules/                    # zsh, kitty, browsers, waybar, rofi, vicinae, neovim,
│       └── desktop/hyprlain/       #   ...and the whole Hyprlain session, parameterised
├── packages/                       # ida-pro, local patches
└── secrets/                        # ragenix-encrypted
```

## Local-only dependencies

Two flake inputs point at content that isn't in this repo:

- **`hyprlain-src`** — Hyprlain dotfiles (wallpapers, icons, session assets), pulled from the public [Ascaniolamp/Hyprlain](https://github.com/Ascaniolamp/Hyprlain) repo. Works out of the box for anyone.
- **`ida-src`** — a pre-extracted IDA Pro install, used to build `pkgs.ida-pro` (see `packages/ida-pro.nix`). IDA Pro is proprietary and unfree, so it can't be committed or fetched — `ida/` at the repo root is gitignored and must exist locally (owner-provided). This input is pinned to an absolute path specific to the machine it was authored on. To build this flake somewhere else, override it:

  ```bash
  nix build .#nixosConfigurations.turing.config.system.build.toplevel \
    --override-input ida-src path:/absolute/path/to/your/ida
  ```

  Both hosts install it now, so both need the directory. To copy it to the other machine:

  ```bash
  rsync -a --delete ~/mixos/ida/ cerf:/home/maru/mixos/ida/   # ~1.1 GiB
  rsync -a ~/.idapro/ cerf:/home/maru/.idapro/                # licence + settings
  ```

  If you don't have IDA Pro, drop `ida-pro` from the `home.packages` list in
  `home/hosts/*/default.nix` and the `ida-src` input / `idaOverlay` from `flake.nix`.

## Quick Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake ~/mixos#turing   # or #cerf

# Update flake inputs
nix flake update

# Rebuild and update
update  # (alias defined in zsh config)

# Create a snapshot
sudo btrfs subvolume snapshot / /.snapshots/$(date +%Y%m%d-%H%M%S)

# List snapshots
sudo btrfs subvolume list /

# Garbage collect old generations
sudo nix-collect-garbage --delete-older-than 7d
```

## Installed Software

### System
- **WM**: Hyprland
- **Terminal**: Kitty
- **Shell**: Zsh with Oh-My-Zsh and Starship
- **Audio**: PipeWire
- **Launcher**: Rofi
- **Bar**: Waybar
- **File Manager**: Thunar
- **Notifications**: Dunst

### Development
- Neovim
- VSCode
- Git with credentials management
- direnv for automatic environment switching

### Utilities
- fzf (fuzzy finder)
- ripgrep (fast grep)
- fd (fast find)
- eza (modern ls)
- bat (better cat)
- btop (system monitor)

## Adding a New Module

### System Module

1. Create `modules/services/myservice.nix`:

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.modules.services.myservice;
in
{
  options.modules.services.myservice = {
    enable = lib.mkEnableOption "My Service";
  };

  config = lib.mkIf cfg.enable {
    # Your configuration here
  };
}
```

2. Import in `hosts/turing/default.nix`:

```nix
imports = [
  ../../modules/services/myservice.nix
];

modules.services.myservice.enable = true;
```

### Home Manager Module

1. Create `home/modules/app/myapp.nix`:

```nix
{ config, pkgs, ... }:

{
  programs.myapp = {
    enable = true;
    # Configuration
  };
}
```

2. Import in `home/default.nix`:

```nix
imports = [
  ./modules/app/myapp.nix
];
```

## Managing Secrets

```bash
# Generate age key (first time only)
mkdir -p ~/.config/age
age-keygen -o ~/.config/age/keys.txt

# Get your public key
age-keygen -y ~/.config/age/keys.txt

# Add to secrets/secrets.nix
# Then create/edit a secret
ragenix -e secrets/mysecret.age
```

Use in configuration:

```nix
age.secrets.mysecret = {
  file = ./secrets/mysecret.age;
  owner = "yourusername";
};

# Reference with: config.age.secrets.mysecret.path
```

## Theming

Stylix automatically themes all applications based on the wallpaper defined in `hosts/turing/default.nix`.

To change the theme:

1. **Using a wallpaper**:
```nix
stylix.image = /path/to/wallpaper.png;
```

2. **Using a base16 scheme**:
```nix
stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
```

Available schemes: https://github.com/tinted-theming/schemes

## Rollback Strategies

### 1. Boot Previous Generation

Reboot → Select older generation in systemd-boot menu

### 2. BTRFS Snapshot Rollback

```bash
# List snapshots
sudo btrfs subvolume list /

# Boot from USB, then:
sudo cryptsetup open /dev/sdX2 crypted
sudo mount -o subvol=@root /dev/mapper/crypted /mnt
sudo btrfs subvolume delete /mnt
sudo btrfs subvolume snapshot /.snapshots/DATE /mnt
```

## Maintenance

```bash
# Clean old generations (older than 7 days)
sudo nix-collect-garbage --delete-older-than 7d

# Optimize nix store
nix-store --optimise

# Check disk usage
compsize /
ncdu /nix/store

# Update all inputs
nix flake update

# Check for issues
nixos-rebuild dry-build --flake ~/.dotfiles#turing
```

## Customization Ideas

- [ ] Add automatic snapshots before rebuild (systemd hook)
- [ ] Set up remote builders for faster rebuilds
- [ ] Add more desktop apps based on your workflow
- [ ] Configure backup solution (e.g., restic)
- [ ] Set up development environments per project
- [ ] Add custom scripts to `packages/`
- [ ] Configure printer/scanner support
- [ ] Set up VM with virt-manager
- [ ] Add gaming support (Steam, Wine)

## Troubleshooting

### Build fails with "hash mismatch"

```bash
nix flake lock --update-input <input-name>
```

### Home Manager activation fails

```bash
# Check what changed
home-manager generations

# Rollback
/nix/store/xxx-home-manager-generation/activate
```

### System won't boot after update

Boot into previous generation from systemd-boot menu.

### Secrets not decrypting

```bash
# Check age key exists
ls -la ~/.config/age/keys.txt

# Verify secret has correct public key
cat secrets/secrets.nix
```

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Stylix Docs](https://stylix.danth.me/)
- [NixOS Search](https://search.nixos.org/)

## License

MIT
