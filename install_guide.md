# NixOS Installation Guide - Secondary SSD

This guide will help you install NixOS with this flake configuration on a secondary SSD while keeping your Arch installation intact.

## Prerequisites

- Your Arch system with systemd-boot
- A secondary SSD (will be completely wiped)
- Internet connection
- Backup of any important data

## Step 1: Identify Your Secondary SSD

From your Arch system:

```bash
lsblk
```

Identify your secondary SSD. It will be something like:
- `/dev/nvme1n1` (if it's an NVMe drive)
- `/dev/sdb` (if it's a SATA drive)

**IMPORTANT**: Double-check this! The installation will WIPE this drive completely.

## Step 2: Download NixOS ISO

```bash
# Download the latest NixOS unstable ISO
cd ~/Downloads
wget https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso

# Create a bootable USB
sudo dd if=latest-nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=sync
# Replace /dev/sdX with your USB drive (check with lsblk)
```

## Step 3: Boot into NixOS ISO

1. Reboot your computer
2. Press F12/F2/Del (depending on your motherboard) to access boot menu
3. Select the USB drive
4. Boot into NixOS installer

## Step 4: Set Up the Live Environment

Once booted into the NixOS installer:

```bash
# Set up networking
sudo systemctl start wpa_supplicant

# If using WiFi:
sudo wpa_passphrase "YOUR_SSID" "YOUR_PASSWORD" | sudo tee /etc/wpa_supplicant.conf
sudo systemctl restart wpa_supplicant

# Test internet connection
ping -c 3 nixos.org

# Set up a temporary password for root (for SSH if needed)
sudo passwd
```

## Step 5: Clone Your Configuration

```bash
# Install git in the live environment
nix-shell -p git

# Clone your dotfiles repo
git clone https://github.com/yourusername/dotfiles.git /mnt/etc/nixos
cd /mnt/etc/nixos
```

## Step 6: Update Configuration for Your Hardware

### 6.1: Edit `hosts/turing/disko.nix`

```bash
# Find your secondary SSD device
lsblk

# Edit disko.nix
nano hosts/turing/disko.nix
```

Change this line:
```nix
device = "/dev/sdX";  # Change to your actual device
```

To your actual device, for example:
```nix
device = "/dev/nvme1n1";  # or /dev/sdb, etc.
```

### 6.2: Update Your Username

Edit the flake.nix:
```bash
nano flake.nix
```

Change:
```nix
username = "yourusername";
```

To your actual desired username.

### 6.3: Update User Information

Edit `modules/core/users.nix`:
```bash
nano modules/core/users.nix
```

Change the description to your actual name.

Edit `home/default.nix`:
```bash
nano home/default.nix
```

Update your git configuration with your name and email.

## Step 7: Partition and Format with Disko

```bash
# This will WIPE your secondary SSD!
# Double-check the device in hosts/turing/disko.nix

# Run disko to partition and format
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko /mnt/etc/nixos/hosts/turing/disko.nix

# You'll be prompted for an encryption password - remember this!
```

## Step 8: Generate Hardware Configuration

```bash
# Generate hardware config for your system
nixos-generate-config --no-filesystems --root /mnt

# Move the hardware config to the right place
sudo mv /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/hosts/turing/hardware.nix
```

## Step 9: Initial Installation

```bash
# Install NixOS
sudo nixos-install --root /mnt --flake /mnt/etc/nixos#turing

# Set root password when prompted
```

This will take a while as it downloads and builds everything.

## Step 10: First Boot Setup

```bash
# Reboot into your new NixOS system
reboot
```

In systemd-boot menu, you should now see NixOS entries alongside your Arch entry.

### After Booting into NixOS:

```bash
# Log in with your user account (password: "changeme")

# Change your password immediately
passwd

# Your dotfiles are in /etc/nixos, but let's move them to your home
sudo chown -R $(whoami):users /etc/nixos
mv /etc/nixos ~/.dotfiles

# Update the home path if needed
cd ~/.dotfiles

# The system is already installed, but let's verify
sudo nixos-rebuild switch --flake ~/.dotfiles#turing
```

## Step 11: Set Up Secrets (Optional but Recommended)

```bash
# Generate an age key
mkdir -p ~/.config/age
age-keygen -o ~/.config/age/keys.txt

# View your public key
age-keygen -y ~/.config/age/keys.txt

# Create secrets.nix
mkdir -p ~/.dotfiles/secrets
cat > ~/.dotfiles/secrets/secrets.nix << 'EOF'
let
  yourkey = "age1...";  # Paste your public key here
in
{
  "example_secret.age".publicKeys = [ yourkey ];
}
EOF

# Install ragenix CLI
nix profile install github:yaxitech/ragenix

# Create a test secret
ragenix -e ~/.dotfiles/secrets/example_secret.age
# This will open your $EDITOR to enter the secret
```

## Step 12: Customize Your System

Now that everything is working, you can customize:

1. **Wallpaper**: Download a wallpaper and update the URL in `hosts/turing/default.nix`
2. **Monitor configuration**: Edit `home/modules/desktop/hyprland.nix` monitor settings
3. **Keybindings**: Adjust Hyprland keybindings to your preference
4. **Applications**: Add more packages to `home/default.nix`

After any changes:
```bash
sudo nixos-rebuild switch --flake ~/.dotfiles#turing
```

## Step 13: Create a Snapshot (For Rollbacks)

```bash
# Create a manual snapshot before major changes
sudo btrfs subvolume snapshot / /.snapshots/$(date +%Y%m%d-%H%M%S)

# List snapshots
sudo btrfs subvolume list /
```

## Dual Boot Management

Your systemd-boot menu should show both NixOS and Arch entries. To change the default:

```bash
# From NixOS:
sudo bootctl set-default nixos-generation-1.conf
# Or from Arch:
sudo bootctl set-default arch.conf
```

## Common Issues & Solutions

### Issue: "command not found" after installation

**Solution**: You might need to log out and log back in, or reboot once more.

### Issue: Hyprland won't start

**Solution**: Check if you have proper graphics drivers. Edit `modules/desktop/hyprland.nix` and ensure the right GPU drivers are enabled.

For NVIDIA:
```bash
# Add to hosts/turing/default.nix
imports = [
  ../../modules/hardware/nvidia.nix
];
```

Then create `modules/hardware/nvidia.nix`:
```nix
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;  # Use proprietary drivers
    nvidiaSettings = true;
  };
}
```

### Issue: Can't connect to WiFi

**Solution**: 
```bash
nmtui  # NetworkManager TUI
# Select "Activate a connection" and choose your network
```

### Issue: Wrong keyboard layout

**Solution**: Edit `modules/desktop/hyprland.nix` and change `kb_layout`.

## Rolling Back

If something breaks after an update:

### Option 1: Boot into previous generation
1. Reboot
2. In systemd-boot menu, select an older NixOS generation
3. Once booted, make it the default:
```bash
sudo /nix/var/nix/profiles/system-*-link/bin/switch-to-configuration boot
```

### Option 2: BTRFS snapshot rollback
1. Boot from USB
2. Mount the encrypted partition:
```bash
cryptsetup open /dev/sdX2 crypted
mount -o subvol=@root /dev/mapper/crypted /mnt
cd /mnt
```
3. Delete broken root:
```bash
btrfs subvolume delete /mnt
```
4. Restore from snapshot:
```bash
btrfs subvolume snapshot /.snapshots/YYYY-MM-DD /mnt
```

## Updating the System

```bash
# Update flake inputs
cd ~/.dotfiles
nix flake update

# Rebuild with new inputs
sudo nixos-rebuild switch --flake ~/.dotfiles#turing

# Or use the alias (from zsh config)
update
```

## Getting Help

- NixOS Manual: https://nixos.org/manual/nixos/stable/
- Hyprland Wiki: https://wiki.hyprland.org/
- Home Manager Manual: https://nix-community.github.io/home-manager/

## Next Steps

1. Set up your development environment
2. Install your preferred applications
3. Configure additional services
4. Set up automatic BTRFS snapshots with a systemd timer
5. Explore NixOS options: https://search.nixos.org/options

Enjoy your new NixOS system!
