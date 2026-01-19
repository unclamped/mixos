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

## Structure

```
.
├── flake.nix           # Main flake configuration
├── hosts/
│   └── turing/         # Host-specific config
│       ├── default.nix
│       ├── disko.nix   # Disk layout
│       └── hardware.nix
├── modules/
│   ├── core/           # Core system modules
│   ├── services/       # System services
│   ├── desktop/        # Desktop environment
│   └── hardware/       # Hardware-specific
├── home/               # Home Manager configuration
│   ├── default.nix
│   └── modules/        # User application configs
└── secrets/            # Encrypted secrets
```

## Quick Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake ~/.dotfiles#turing

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
