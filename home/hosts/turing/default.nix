{ config, pkgs, inputs, username, lib, ... }:

# ─── turing ─────────────────────────────────────────────────────────────────
# The desktop: NVIDIA, three monitors, games, VR, reverse engineering, music.
# Everything shared with cerf comes from ../../default.nix; this file is only
# the difference.

{
  imports = [
    ../../default.nix

    # The three-monitor Hyprlain desk (monitors, workspace slices, the ambient
    # CRT dashboard). Sets options on ../../modules/desktop/hyprlain.
    ./hyprlain-desk.nix

    # turing-only
    ../../modules/desktop/spicetify.nix
    ../../modules/desktop/audio-eq.nix
    ../../modules/gaming/vr.nix
  ];

  # The plain fallback session mirrors the desk's per-monitor workspace slices
  # (5 each here rather than Hyprlain's 9) so switching sessions doesn't
  # completely change how SUPER+N behaves.
  hyprlandFallback = {
    wsBases = { "HDMI-A-1" = 0; "DP-3" = 5; };
    autostart = ''
      hl.exec_cmd("equibop")
      hl.exec_cmd("senpai")
      hl.exec_cmd("ferdium")
    '';
    extraConfig = ''
      hl.bind("SUPER + S", hl.dsp.exec_cmd("steam"))
      hl.window_rule({ name = "steam-stay-focused", match = { class = "^(steam)$", title = "^()" }, stay_focused = true })
      hl.window_rule({ name = "steam-minsize",      match = { class = "^(steam)$", title = "^()" }, min_size = "1 1" })
    '';
  };

  home.packages = with pkgs; [
    # Communication
    telegram-desktop
    ferdium
    feishin
    # feishin-debug: launches Feishin (Electron) with the CDP remote-debugging
    # port open so CSS can be iterated live via chrome-devtools. Isolates
    # nothing — same profile — but the port is only up while this is running.
    (writeShellScriptBin "feishin-debug" ''
      exec ${feishin}/bin/feishin \
        --remote-debugging-port=9222 \
        --remote-allow-origins='*' "$@"
    '')

    # Music apps (Spotify is provided, themed, by spicetify — see spicetify.nix)
    millisecond

    # PipeWire-native volume/output mixer. WiVRn exposes a normal PipeWire
    # Audio/Sink node while a headset session is active, so it just shows up
    # under Output Devices here -- no extra pipewire config needed to route
    # audio to it.
    pwvucontrol

    # Chat / terminal clients
    weechat

    # Reverse engineering. ida-pro comes from the overlay in flake.nix, which
    # is fed by the gitignored ida/ directory; ghidra is plain nixpkgs.
    ida-pro
    ghidra
  ];

  # Feishin custom theme (desktop). Feishin watches ~/.config/feishin/Themes for
  # *.json theme files and inlines their linked stylesheets when active. Select
  # "Lain" under Settings → General → Theme. The JSON drives Feishin's palette
  # tokens; lain.css layers the TUI look (monospace, boxy, pink borders).
  xdg.configFile."feishin/Themes/lain.json".text = builtins.toJSON {
    mode = "dark";
    extends = "defaultDark";
    colors = {
      background = "rgb(0, 0, 0)";
      background-alternate = "rgb(10, 10, 10)";
      surface = "rgb(26, 26, 26)";
      surface-foreground = "rgb(193, 180, 142)";
      foreground = "rgb(193, 180, 142)";
      foreground-muted = "rgb(150, 140, 110)";
      primary = "rgb(206, 118, 136)";
      black = "rgb(0, 0, 0)";
      white = "rgb(232, 223, 192)";
      state-error = "rgb(206, 118, 136)";
      state-info = "rgb(140, 158, 158)";
      state-success = "rgb(168, 160, 110)";
      state-warning = "rgb(160, 89, 105)";
    };
    app = {
      root-font-size = "15px";
      scrollbar-size = "8px";
      scrollbar-handle-background = "rgb(206, 118, 136)";
      scrollbar-handle-hover-background = "rgb(186, 106, 123)";
      scrollbar-track-background = "rgb(10, 10, 10)";
      overlay-header = "rgba(0, 0, 0, 0.85)";
      overlay-subheader = "rgba(0, 0, 0, 0.7)";
    };
    mantineOverride = { primaryShade = { dark = 6; }; };
    # No stylesheets ref: the CSS lives at ~/.config/feishin/custom.css, which
    # Feishin auto-loads globally (Themes/*.css are only inlined when named as
    # the theme file, and must be exactly custom.css to be picked up).
    stylesheets = [ ];
  };

  # Feishin auto-detects and applies ~/.config/feishin/custom.css on top of the
  # active theme — it MUST be named custom.css (a differently-named file under
  # Themes/ is ignored). This is the TUI Lain layer (monospace, boxy, pink).
  xdg.configFile."feishin/custom.css".text = ''
    /* ===== Lain TUI theme for Feishin =====================================
       Monospace, boxy (no rounded corners), pink #CE7688 on pure black, with
       framed panels — matching the system24 / spicetify-text Lain aesthetic. */

    :root {
      --lain-pink: #ce7688;
      --lain-rose: #ba6a7b;
      --lain-tan:  #c1b48e;
      --lain-dim:  #968c6e;
      --lain-bg:   #000000;
      --lain-surface: #0d0d0d;
    }

    /* monospace everywhere */
    *, *::before, *::after {
      font-family: "AdwaitaMono Nerd Font", "DM Mono", "JetBrains Mono", monospace !important;
      letter-spacing: -0.03ch;
    }

    /* boxy — kill rounded corners across the app */
    *, .mantine-Paper-root, .mantine-Card-root, .mantine-Button-root,
    .mantine-Input-input, button, input, img, [class*="Card"], [class*="album"] {
      border-radius: 0 !important;
    }

    /* pink framing on the major surfaces / cards */
    .mantine-Paper-root,
    .mantine-Card-root,
    [class*="PlayerbarControls"],
    [class*="Sidebar"],
    [class*="sidebar"] {
      border: 1px solid rgba(206, 118, 136, 0.5) !important;
      background: var(--lain-bg) !important;
    }

    /* accent: links, primary buttons, active states */
    a, .mantine-Anchor-root { color: var(--lain-pink) !important; }
    .mantine-Button-filled,
    [class*="button-primary"],
    [data-active="true"] {
      background: var(--lain-pink) !important;
      color: #000 !important;
    }

    /* now-playing progress + volume sliders in pink */
    .mantine-Slider-bar,
    [class*="progress"] [class*="filled"] { background: var(--lain-pink) !important; }

    /* table rows: subtle pink hover, tan text */
    [class*="Row"]:hover, tr:hover {
      background: rgba(206, 118, 136, 0.12) !important;
    }
    [class*="Row"], td, .mantine-Text-root { color: var(--lain-tan); }

    /* dim secondary text (artists, timestamps, counts) */
    [class*="secondary"], [class*="muted"], [class*="subtitle"] {
      color: var(--lain-dim) !important;
    }

    /* scrollbars: thin pink */
    ::-webkit-scrollbar { width: 8px; height: 8px; }
    ::-webkit-scrollbar-thumb { background: var(--lain-pink); border-radius: 0; }
    ::-webkit-scrollbar-track { background: var(--lain-surface); }
  '';

  # Discord: the full plugin loadout. cerf deliberately runs a much smaller
  # set (see ../cerf/default.nix) — this machine has the headroom.
  nixcordProfile = {
    installDiscord = true;

    plugins = {
      accountPanelServerProfile.enable = true;
      altKrispSwitch.enable = true;
      alwaysAnimate.enable = true;
      alwaysExpandProfiles.enable = true;
      alwaysExpandRoles.enable = true;
      alwaysTrust.enable = true;
      bannersEverywhere.enable = true;
      betterActivities.enable = true;
      betterAudioPlayer = {
        enable = true;
        oscilloscope = false;
      };
      betterBanReasons.enable = true;
      betterForwards.enable = true;
      betterGifPicker.enable = true;
      betterInvites.enable = true;
      betterRoleContext.enable = true;
      betterSessions = {
        enable = true;
        backgroundCheck = true;
      };
      betterSettings.enable = true;
      biggerStreamPreview.enable = true;
      blurNsfw.enable = true;
      cancelFriendRequest.enable = true;
      channelBadges.enable = false;
      characterCounter.enable = true;
      cleanerChannelGroups.enable = true;
      clearUrls.enable = true;
      clickableRoles.enable = true;
      consoleJanitor = {
        enable = true;
        disableLoggers = true;
      };
      copyFileContents.enable = true;
      copyStickerLinks.enable = true;
      copyUserUrls.enable = true;
      crashHandler.enable = true;
      cursorBuddy = {
        enable = true;
        outlineColor = "#FF0084";
      };
      customTimestamps = {
        formats = {
          enable = false;
        };
      };
      dearrow.enable = true;
      declutter = {
        enable = true;
        removeAvatarDecoration = true;
        removeQuestsAboveDms = true;
        removeShopAboveDms = true;
      };
      decodeBase64.enable = true;
      disableDeepLinks.enable = true;
      equibopStreamFixes.enable = true;
      equicordHelper.enable = true;
      expressionCloner.enable = true;
      fakeNitro.enable = true;
      favouriteAnything.enable = true;
      fixCodeblockGap.enable = true;
      fixFileExtensions.enable = true;
      fixImagesQuality.enable = true;
      fixYoutubeEmbeds.enable = true;
      forceOwnerCrown.enable = true;
      fullSearchContext.enable = true;
      fullUserInChatbox.enable = true;
      ghosted.enable = true;
      gifMaker.enable = true;
      globalBadges.enable = true;
      greetStickerPicker.enable = true;
      homeTyping.enable = true;
      idleAutoRestart.enable = true;
      imageFilename.enable = true;
      imageLink.enable = true;
      imageZoom.enable = true;
      iRememberYou.enable = true;
      keepCurrentChannel.enable = true;
      limitlessScreenshare.enable = true;
      markdownTables.enable = true;
      messageLinkTooltip.enable = true;
      messageLogger.enable = true;
      messageLoggerEnhanced.enable = true;
      middleClickTweaks.enable = true;
      moreUserTags = {
        enable = true;
        tagSettings = {
          administrator = {
            enable = false;
          };
          chatModerator = {
            enable = false;
          };
          moderator = {
            enable = false;
          };
          moderatorStaff = {
            enable = false;
          };
          owner = {
            enable = false;
          };
          voiceModerator = {
            enable = false;
          };
          webhook = {
            enable = false;
          };
          enable = false;
        };
      };
      newPluginsManager.enable = true;
      noMaskedUrlPaste.enable = true;
      noNitroUpsell.enable = true;
      noOnboardingDelay.enable = true;
      noRpc.enable = true;
      noTypingAnimation.enable = true;
      onePingPerDm.enable = true;
      permissionsViewer.enable = true;
      platformIndicators.enable = true;
      questify = {
        enable = true;
        disableQuestsEverything = true;
      };
      relationshipNotifier.enable = true;
      richMagnetLinks.enable = true;
      roleColorEverywhere.enable = true;
      searchFix.enable = true;
      shikiCodeblocks = {
        enable = true;
        theme = "https://cdn.jsdelivr.net/gh/shikijs/textmate-grammars-themes@bc5436518111d87ea58eb56d97b3f9bec30e6b83/packages/tm-themes/themes/gruvbox-dark-hard.json";
      };
      showBadgesInChat.enable = false;
      showConnections.enable = true;
      showMeYourName.enable = true;
      sortFriends.enable = true;
      splitLargeMessages.enable = true;
      typingTweaks.enable = true;
      unindent.enable = true;
      viewRaw.enable = true;
      voiceDownload.enable = true;
      webContextMenus.enable = true;
      webKeybinds.enable = true;
      webScreenShareFixes.enable = true;
      whoReacted.enable = true;
      xsOverlay.enable = true;
      zipPreview.enable = true;
    };

    extraConfig = {
      fakeNitro = {
        useHyperLinks = true;
      };
      fontLoader = {
        applyOnClodeBlocks = false;
      };
      globalBadges = {
        showRa1ncord = true;
      };
      messageClickActions = {
        enableDeleteOnClick = true;
        enableDoubleClickToEdit = true;
        enableDoubleClickToReply = true;
        requireModifier = false;
      };
      noBlockedMessages = {
        applyToIgnoredUsers = true;
        ignoreBlockedMessages = false;
        ignoreMessages = false;
      };
      platformIndicators = {
        badges = true;
      };
      showHiddenChannels = {
        hideUnreads = true;
      };
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
      translate = {
        shavian = true;
        sitelen = true;
        target = "en";
        toki = true;
      };
    };
  };
}
