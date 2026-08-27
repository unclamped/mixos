{ config, pkgs, lib, inputs, username, ... }:

# Discord / Equibop via nixcord, shared by every host.
#
# The LOOK is shared and non-negotiable (that's the point of the Hyprlain
# theme); the PLUGIN SET is per-host, because a 2-core Broadwell laptop taken
# to university does not want turing's full 90-plugin loadout. Set
# `nixcordProfile.plugins` / `.extraConfig` from home/hosts/<host>.

let
  cfg = config.nixcordProfile;

  # Equibop is an Electron app, and Electron does not put "equibop" in any
  # process's argv[0] — the main process shows up as the electron binary with
  # the app.asar path as its first argument, and there's a separate arRPC
  # helper. That is why `pkill equibop` reports nothing and changes nothing.
  #
  # Match on the asar path instead (the store path changes on every update, so
  # match the stable "Equibop/resources" suffix), kill the whole tree, wait for
  # it to actually go away, then start it again detached from this shell.
  equibopRestart = pkgs.writeShellScriptBin "equibop-restart" ''
    set -u

    pattern='Equibop/resources'

    if ${pkgs.procps}/bin/pgrep -u "$USER" -f "$pattern" >/dev/null 2>&1; then
      echo "stopping equibop..."
      ${pkgs.procps}/bin/pkill -u "$USER" -f "$pattern" || true

      # Give it a moment to exit cleanly, then insist.
      for _ in $(seq 1 20); do
        ${pkgs.procps}/bin/pgrep -u "$USER" -f "$pattern" >/dev/null 2>&1 || break
        sleep 0.25
      done
      if ${pkgs.procps}/bin/pgrep -u "$USER" -f "$pattern" >/dev/null 2>&1; then
        echo "still running, sending SIGKILL..."
        ${pkgs.procps}/bin/pkill -9 -u "$USER" -f "$pattern" || true
        sleep 1
      fi
    else
      echo "equibop was not running"
    fi

    # Equibop keeps a single-instance lock; after an unclean kill (which is the
    # usual reason for running this) the stale lock makes the next launch exit
    # silently instead of opening a window.
    rm -f "''${XDG_CONFIG_HOME:-$HOME/.config}"/equibop/SingletonLock \
          "''${XDG_CONFIG_HOME:-$HOME/.config}"/equibop/SingletonCookie \
          "''${XDG_CONFIG_HOME:-$HOME/.config}"/equibop/SingletonSocket 2>/dev/null || true

    echo "starting equibop..."
    ${pkgs.coreutils}/bin/nohup equibop >/dev/null 2>&1 &
    disown 2>/dev/null || true
    echo "done"
  '';
in
{
  options.nixcordProfile = {
    plugins = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "programs.nixcord.config.plugins for this host.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "programs.nixcord.extraConfig.plugins for this host.";
    };

    installDiscord = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also install stock (unmodded) Discord alongside Equibop.";
    };
  };

  imports = [ inputs.nixcord.homeModules.nixcord ];

  config = {
    home.packages = [ equibopRestart ];

    # Don't let Stylix theme the nixcord clients. Its nixcord target writes
    # equibop/themes/stylix.theme.css AND force-adds it to enabledThemes,
    # layering base16 colors over our Lain system24 quickCss. We own the
    # Discord look via quickCss, so turn Stylix off here.
    stylix.targets.nixcord.enable = false;

    programs.nixcord = {
      enable = true;
      user = username;

      # refact0r/system24 (a maintained TUI-style Discord theme) recolored to
      # the Lain palette, applied to Equibop/Discord as quickCss. Shared by
      # every host so Discord looks the same everywhere, whatever plugins are
      # loaded.
      quickCss = builtins.readFile ../desktop/system24-hyprlain.theme.css;

      # Stock Discord is optional. When it IS installed with neither Vencord
      # nor Equicord enabled, nixcord warns on every rebuild; we genuinely want
      # it unmodded (Equibop is the modded client), so acknowledge the warning
      # rather than leaving it to scroll past forever.
      discord = {
        enable = cfg.installDiscord;
        settings.SKIP_HOST_UPDATE = true;
        silenceNoModClientWarning = true;
      };

      equibop = {
        enable = true;
        autoscroll.enable = true;
      };

      config.useQuickCss = true;
      config.plugins = cfg.plugins;
      extraConfig.plugins = cfg.extraConfig;
    };
  };
}
