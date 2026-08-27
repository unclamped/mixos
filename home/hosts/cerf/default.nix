{ config, pkgs, inputs, username, lib, ... }:

# ─── cerf ───────────────────────────────────────────────────────────────────
# The EliteBook 840 G2: CCNAv7 / CompSci / cybersec laptop. Everything shared
# with turing comes from ../../default.nix; this file is only the difference.

{
  imports = [
    ../../default.nix

    # Single-panel Hyprlain laptop session (one output, battery module,
    # touchpad gestures, and the split internal/external keyboard layout).
    # Sets options on ../../modules/desktop/hyprlain.
    ./hyprlain-laptop.nix
  ];

  # One output, so no per-monitor workspace slicing in the fallback session
  # either — SUPER+1..5 are plain global workspaces (the module's default).
  hyprlandFallback.autostart = ''
    hl.exec_cmd("equibop")
  '';

  home.packages = with pkgs; [
    # Networking / CCNAv7 / cybersec extras beyond the system package set
    # (the CLI tools are installed system-wide in hosts/cerf/default.nix;
    # these are the user-facing / GUI / scripting ones)
    python314
    python314Packages.scapy
    remmina   # RDP/VNC/SSH client — useful for reaching lab VMs
    filezilla

    # Reverse engineering. ghidra needs nothing but nixpkgs; ida-pro comes
    # from the overlay in flake.nix and therefore needs the (gitignored) ida/
    # directory to exist at /home/maru/mixos/ida on THIS machine too — see the
    # note on the ida-src input.
    ghidra
    ida-pro
  ];

  # Keep kitty on Xwayland on this machine. Native Wayland here loses terminal
  # transparency, while this workaround keeps transparent backgrounds working.
  programs.kitty.settings.linux_display_server = lib.mkForce "x11";

  # Discord: a deliberately small plugin set. This is a 2-core Broadwell with
  # 15G of RAM that spends its day on battery in a lecture hall — turing's
  # ~90-plugin loadout is a real cost here. Same Lain theme though (the
  # quickCss lives in the shared module), so it still looks identical.
  nixcordProfile = {
    installDiscord = false;

    plugins = {
      # Quality-of-life that costs essentially nothing
      alwaysTrust.enable = true;
      betterSettings.enable = true;
      clearUrls.enable = true;
      crashHandler.enable = true;
      consoleJanitor = {
        enable = true;
        disableLoggers = true;
      };
      declutter = {
        enable = true;
        removeAvatarDecoration = true;
        removeQuestsAboveDms = true;
        removeShopAboveDms = true;
      };
      equibopStreamFixes.enable = true;
      equicordHelper.enable = true;
      fixCodeblockGap.enable = true;
      fixYoutubeEmbeds.enable = true;
      keepCurrentChannel.enable = true;
      messageLinkTooltip.enable = true;
      noNitroUpsell.enable = true;
      noOnboardingDelay.enable = true;
      # No Rich Presence: it is pure background chatter on a battery machine.
      noRpc.enable = true;
      questify = {
        enable = true;
        disableQuestsEverything = true;
      };
      showMeYourName.enable = true;
      silentTyping.enable = true;
      typingTweaks.enable = true;
      viewRaw.enable = true;
      webContextMenus.enable = true;
      webKeybinds.enable = true;

      # Deliberately OFF here (all enabled on turing): messageLogger*,
      # betterActivities, alwaysAnimate, bannersEverywhere, imageZoom,
      # shikiCodeblocks, cursorBuddy, dearrow — all of them either animate
      # constantly, hold extra state, or make network requests.
    };

    extraConfig = {
      showMeYourName = {
        displayNames = false;
        friendNicknames = "dms";
        inReplies = false;
        mode = "user-nick";
      };
      silentTyping = {
        contextMenu = true;
        isEnabled = true;
        showIcon = false;
      };
    };
  };
}
