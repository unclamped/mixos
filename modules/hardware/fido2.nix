{ pkgs, username, ... }:

{
  # Udev rules so FIDO2 devices are accessible without root
  services.udev.packages = [ pkgs.libfido2 ];

  # Add the user to plugdev so FIDO2 HID devices are readable
  users.users.${username}.extraGroups = [ "plugdev" ];

  # PAM U2F / FIDO2 — "sufficient" lets the key substitute for a password;
  # falls back to password if no key is present or touch times out.
  security.pam.u2f = {
    enable = true;
    # Prompt the user to touch the key
    settings.cue = true;
    # Key mappings live in ~/.config/Yubico/u2f_keys (per-user, not system-wide)
    # Register a new key with: nix-shell -p pam_u2f --run pamu2fcfg >> ~/.config/Yubico/u2f_keys
    control = "sufficient";
  };

  # Tools for inspecting and managing FIDO2 tokens
  environment.systemPackages = with pkgs; [
    libfido2   # fido2-token, fido2-assert, fido2-cred
    pam_u2f    # pamu2fcfg (registration helper)
  ];
}
