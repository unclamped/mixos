{ config, pkgs, lib, ... }:

# Laptop battery-life tuning. Written for cerf (Intel Core i5-5300U /
# Broadwell, HD Graphics 5500) — turing is a desktop that's always on AC, so
# this module is imported only by cerf, not modules/core.

{
  services.tlp = {
    enable = true;
    settings = {
      # Full performance while charging, conservative on battery.
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # PCIe Active State Power Management — one of the bigger idle-power
      # wins available on this chipset.
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # Let PCI(e) devices (SATA controller, etc.) autosuspend when idle on
      # battery. The GPU is deliberately excluded below — this Broadwell
      # i915 has known runtime-PM bugs where PCI-level autosuspend leaves
      # the device stuck in a low-power state, breaking DRI/EGL context
      # creation (e.g. kitty's "Failed to create GLFWwindow") until reboot.
      # i915 already manages its own power states internally (RC6), so
      # this doesn't give up any real savings.
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";
      RUNTIME_PM_DRIVER_BLACKLIST = "mei_me i915";

      USB_AUTOSUSPEND = 1;

      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";

      SOUND_POWER_SAVE_ON_AC = 0;
      SOUND_POWER_SAVE_ON_BAT = 1;
    };
  };

  # power-profiles-daemon manages the same knobs as TLP and the two must
  # never run together — not enabled anywhere currently, but force it off so
  # a future module (e.g. a desktop-environment default) can't silently pull
  # it in and conflict.
  services.power-profiles-daemon.enable = lib.mkForce false;

  # Proactively trims turbo before the Broadwell CPU hits hard thermal
  # throttling, which otherwise wastes power ramping clocks up and down.
  services.thermald.enable = true;

  # Compressed RAM-backed swap, prioritized over the existing 8G btrfs
  # swapfile (hosts/cerf/disko.nix) so routine swapping happens in RAM
  # instead of waking the disk. The swapfile remains as overflow.
  zramSwap = {
    enable = true;
    memoryPercent = 25;
    priority = 10;
  };
}
