{ config, pkgs, inputs, username, lib, ... }:

{
  imports = [
    # Shell
    ./modules/shell/zsh.nix
    
    # Terminal
    ./modules/terminal/kitty.nix

    # Browsers
    ./modules/browsers/browsers.nix
    
    # Desktop
    ./modules/desktop/hyprland.nix
    ./modules/desktop/waybar.nix
    ./modules/desktop/rofi.nix
    ./modules/desktop/vicinae.nix
    ./modules/desktop/hyprlain.nix
    ./modules/desktop/theme-hyprlain.nix
    ./modules/desktop/spicetify.nix
    ./modules/desktop/audio-eq.nix
    
    # Editors
    ./modules/editors/neovim.nix

    # VR (tethered Quest 2)
    ./modules/gaming/vr.nix

    # nixcord Home Manager module
    inputs.nixcord.homeModules.nixcord

    # Vicinae Home Manager module
    inputs.vicinae.homeManagerModules.default
  ];

  # Home Manager settings
  home = {
    username = username;
    homeDirectory = "/home/${username}";
    stateVersion = "26.05";
    
    # User packages
    packages = with pkgs; [
      # Browsers
      firefox
      
      # Communication
      telegram-desktop
      ferdium
      feishin
      # feishin-debug: launches Feishin (Electron) with the CDP remote-debugging
      # port open so CSS can be iterated live via chrome-devtools. Isolated
      # nothing — same profile — but the port is only up while this is running.
      (writeShellScriptBin "feishin-debug" ''
        exec ${feishin}/bin/feishin \
          --remote-debugging-port=9222 \
          --remote-allow-origins='*' "$@"
      '')

      # Media
      mpv
      imv

      # Development
      vscode
      # Music apps (Spotify is provided, themed, by spicetify — see spicetify.nix)
      millisecond
      
      # KDE apps
      ark

      # Utils
      unzip
      tree
      file

      # PipeWire-native volume/output mixer. WiVRn exposes a normal
      # PipeWire Audio/Sink node while a headset session is active, so it
      # just shows up under Output Devices here -- no extra pipewire config
      # needed to route audio to it.
      pwvucontrol

      # Chat / terminal clients
      weechat

      # Reverse engineering
      ida-pro

    ];
    
    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "helium";
      TERMINAL = "kitty";
    };
  };
  
  xdg.configFile."kdeglobals".text = ''
    [General]
    TerminalApplication=kitty
    TerminalService=kitty.desktop
  '';

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

  xdg.dataFile."applications/nvim.desktop".text = ''
    [Desktop Entry]
    Name=Neovim
    GenericName=Text Editor
    Exec=kitty -e nvim %F
    Terminal=false
    Type=Application
    Categories=Utility;TextEditor;
    MimeType=text/plain;text/x-nix;text/markdown;text/css;text/javascript;application/json;application/toml;application/x-yaml;
    Icon=nvim
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory"    = [ "org.kde.dolphin.desktop" ];
      "text/plain"         = [ "nvim.desktop" ];
      "text/x-nix"         = [ "nvim.desktop" ];
      "text/markdown"      = [ "nvim.desktop" ];
      "text/css"           = [ "nvim.desktop" ];
      "text/javascript"    = [ "nvim.desktop" ];
      "application/json"   = [ "nvim.desktop" ];
      "application/toml"   = [ "nvim.desktop" ];
      "application/x-yaml" = [ "nvim.desktop" ];
    };
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Don't let Stylix theme the nixcord clients (Discord + Equibop). Its nixcord
  # target writes equibop/themes/stylix.theme.css AND force-adds it to
  # enabledThemes, layering base16 colors over our Lain system24 quickCss. We own
  # the Discord look via quickCss, so turn Stylix off here.
  stylix.targets.nixcord.enable = false;

  # nixcord via its Home Manager module — installs stock Discord + Equibop
  programs.nixcord = {
    enable = true;
    user = username;

    # refact0r/system24 (a maintained TUI-style Discord theme) recolored to the
    # Lain palette, applied to Equibop/Discord as quickCss. Replaces the stale
    # bundled Hyprlain vesktop CSS. See ./modules/desktop/system24-hyprlain.theme.css.
    quickCss = builtins.readFile ./modules/desktop/system24-hyprlain.theme.css;

    discord = {
      enable = true;
      settings.SKIP_HOST_UPDATE = true;
    };

    equibop = {
      enable = true;
      autoscroll.enable = true;
    };

    config.useQuickCss = true;

    config.plugins = {
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

    extraConfig.plugins = {
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
  
  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "unclamped";

        email =
          lib.concatStrings
            (lib.reverseList
              (lib.stringToCharacters "moc.atonatut@0686raelc"));
      };
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  # The shared id_ed25519 keypair's public half — non-secret, so declared
  # here instead of relying on it being manually copied between hosts (it
  # wasn't: cerf never had it). The private half is ragenix-managed, see
  # modules/core/users.nix's ssh-id-ed25519 secret. Must match the key
  # authorized in hosts/cerf/default.nix's services.openssh config.
  #
  # The comment field (an email) is stored reversed, same as the git email
  # above, so it doesn't sit in cleartext in the repo.
  home.file.".ssh/id_ed25519.pub".text =
    let
      email = lib.concatStrings (lib.reverseList (lib.stringToCharacters "moc.atonatut@0686raelc"));
    in
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDiPiksIGtarfrN0IPEOlOBIpi4qX+M1J/DWPoxexviq ${email}\n";
}
