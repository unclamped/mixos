{ config, pkgs, lib, inputs, ... }:

let
  hl = inputs.hyprlain-src;

  # Package the upstream QML SDDM theme (src/sddm/src/Hyprlain) into the
  # standard themes location so SDDM can discover it by name "Hyprlain".
  # Upstream's Main.qml is Qt5 (QtQuick.Controls 1.4/Styles, QtMultimedia 5.5
  # Audio) which crashes the Qt6 greeter; swap in our Qt6 port.
  #
  # THE fix for "theme doesn't show": SDDM's daemon picks the greeter binary via
  # Greeter::greeterPathForQt(ThemeMetadata::qtVersion()) — it reads a `QtVersion`
  # key from metadata.desktop. Upstream's metadata has NO QtVersion, so SDDM
  # defaults to Qt5, looks for the (nonexistent) `sddm-greeter` binary, logs
  # "requires missing .../sddm-greeter. Using fallback theme." and silently
  # renders its built-in fallback. Breeze works only because it declares
  # QtVersion=6. So we add `QtVersion=6` (points SDDM at sddm-greeter-qt6, which
  # exists). We also add an (empty) theme.conf + ConfigFile marker to match the
  # stock themes' metadata shape.
  hyprlainSddmTheme = pkgs.runCommand "sddm-hyprlain-theme" { } ''
    mkdir -p $out/share/sddm/themes
    cp -r ${hl}/src/sddm/src/Hyprlain $out/share/sddm/themes/Hyprlain
    chmod -R u+w $out/share/sddm/themes/Hyprlain
    cp ${./sddm-hyprlain/Main.qml} $out/share/sddm/themes/Hyprlain/Main.qml
    cp ${./sddm-hyprlain/Sounds.qml} $out/share/sddm/themes/Hyprlain/Sounds.qml
    printf '[General]\n' > $out/share/sddm/themes/Hyprlain/theme.conf
    # Leading newline: upstream metadata.desktop has no trailing newline, so
    # without it the first key would glue onto the Theme-API line.
    printf '\nConfigFile=theme.conf\nQtVersion=6\n' >> $out/share/sddm/themes/Hyprlain/metadata.desktop
  '';
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;

    # Render the greeter under kwin_wayland instead of the default weston nested
    # compositor. On NVIDIA proprietary, weston brings up a black surface; KWin
    # handles the NVIDIA path correctly, so the greeter is actually visible.
    #
    # We spell out the compositor command (mirroring NixOS's `compositorCmds.kwin`)
    # so we can prefix a cursor env: kwin_wayland ignores SDDM's [Theme]
    # CursorTheme and otherwise tries to load a "default" theme that doesn't
    # exist (`kwin_core: Failed to load cursor theme "default"`), leaving no
    # cursor. XCURSOR_THEME/SIZE point it at Bibata (in systemPackages below, so
    # it's on the greeter's XCURSOR_PATH via /run/current-system/sw/share/icons).
    wayland.compositorCommand = lib.concatStringsSep " " [
      "env"
      "XCURSOR_THEME=Bibata-Modern-Classic"
      "XCURSOR_SIZE=24"
      "${lib.getBin pkgs.kdePackages.kwin}/bin/kwin_wayland"
      "--no-global-shortcuts"
      "--no-kactivities"
      "--no-lockscreen"
      "--locale1"
    ];

    # Qt6 SDDM (the only sddm in nixpkgs now). The theme's Main.qml is our Qt6
    # port (see ./sddm-hyprlain/Main.qml); upstream's Qt5 original crashed the
    # greeter, which is why there was no theme and no cursor.
    package = pkgs.kdePackages.sddm;
    theme = "Hyprlain";

    # Qt6 QML runtime modules the theme needs: svg (assets) and the Qt5Compat
    # shim for any legacy QtQuick bits. NOTE: no qtmultimedia — the theme no
    # longer imports QtMultimedia (see ./sddm-hyprlain/Main.qml); when it did,
    # the import failed on the greeter's restricted QML path and the whole
    # theme silently fell back to a blank UI.
    # qtmultimedia puts the QtMultimedia QML module + audio backend on the
    # greeter's import path so Sounds.qml (welcome/deny/bg sounds) can load. It's
    # isolated in a Loader, so if the backend can't reach an audio device the
    # theme still renders — you just won't hear the sounds.
    extraPackages = with pkgs.kdePackages; [
      qtsvg
      qt5compat
      qtmultimedia
    ];

    # The crashed greeter also left no cursor; pin the same cursor the desktop
    # uses so the login screen shows one regardless of the theme.
    settings.Theme.CursorTheme = "Bibata-Modern-Classic";
  };

  # Make the theme discoverable via the system profile
  # (/run/current-system/sw/share/sddm/themes); bibata-cursors so the
  # CursorTheme set above resolves at the greeter.
  environment.systemPackages = [ hyprlainSddmTheme pkgs.bibata-cursors ];

  # Persist SDDM state across the root-wipe so it remembers the last selected
  # session/user (helps the "pick the normal session" fallback).
  environment.persistence."/persist".directories = [ "/var/lib/sddm" ];

  # The greeter runs as the `sddm` user; give it audio-device access so the
  # login sounds can play. (Greeter audio also needs a reachable sound server —
  # if there's none for this user the sounds stay silent, but the theme is
  # unaffected because Sounds.qml is Loader-isolated.)
  users.users.sddm.extraGroups = [ "audio" ];

  # NOTE: a kwinoutputconfig.json was seeded here (2026-08-19) to disable the
  # ambient CRT in the greeter, because kwin_wayland has no kscreen outside a
  # Plasma session and so parks every output at 0,0 — mirroring all three, which
  # is what produced the duplicated cursor and the white band down the right of
  # the wider main monitor. It was removed again during the display bisection:
  # it was never actually tested, and its schema was reverse engineered from
  # kwin's OutputConfigurationStore (strict EDID-identity matching, exact output
  # count), which is too much unverified machinery to carry while chasing a
  # separate intermittent fault. Recover it from git history if the greeter
  # layout becomes worth fixing on its own.

}

