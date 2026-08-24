{ inputs, pkgs, ... }:

# Themed Spotify via spicetify-nix — COLOR-ONLY Lain recolor.
#
# The upstream `text` theme (and the old bundled Hyprlain fork) is a heavy
# *structural* rewrite: it hides cover art, restyles the DOM, and pins layout to
# a specific Spotify build. On the current spicetify-nix Spotify (+ a 1366x768
# panel) its selectors miss and the UI collapses — cut-off text, compressed
# library buttons with no icons, misplaced avatar/search, no artwork. That's not
# individually fixable; the theme is simply incompatible.
#
# So instead of a structural theme we ship a *color-only* scheme: a bare
# color.ini with a single [Hyprlain] section. spicetify's `replaceColors` maps
# those into Spotify's own `--spice-*` CSS variables, so the NATIVE Spotify
# layout is preserved (artwork, icons, spacing all intact) but repainted to the
# Lain palette. This is robust across Spotify updates because it never touches
# the DOM structure.
#
# Note: spicetify-nix installs its own (spiced) Spotify, so plain `spotify` is
# dropped from home.packages.

let
  # Bare color-only theme: just a color.ini (no user.css, no theme.js). Keys are
  # spicetify's standard color slots; replaceColors feeds them to --spice-*.
  lainColorTheme = pkgs.runCommand "spicetify-lain-color" { } ''
    mkdir -p $out
    cat > $out/color.ini <<'EOF'
    [Hyprlain]
    ; Lain palette — pink #CE7688 accent, pure-black bg, tan #C1B48E text.
    text               = C1B48E
    subtext            = 968C6E
    main               = 000000
    main-elevated      = 0A0A0A
    highlight          = 1A1A1A
    highlight-elevated = 2A2A2A
    sidebar            = 000000
    player             = 000000
    card               = 0A0A0A
    shadow             = 000000
    selected-row       = CE7688
    button             = CE7688
    button-active      = CE7688
    button-disabled    = 3A3A3A
    tab-active         = 1A1A1A
    notification       = CE7688
    notification-error = BA6A7B
    misc               = 804654
    accent             = CE7688
    accent-active      = CE7688
    accent-inactive    = 1A1A1A
    banner             = CE7688
    border-active      = CE7688
    border-inactive    = 804654
    header             = 000000
    equalizer          = CE7688
    EOF
  '';
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  # spotify-debug: launches the spiced Spotify (CEF) with the CDP
  # remote-debugging port open so its CSS/DOM can be inspected and iterated live
  # via chrome-devtools. Only exposes the port while running.
  home.packages = [
    (pkgs.writeShellScriptBin "spotify-debug" ''
      exec spotify \
        --remote-debugging-port=9222 \
        --remote-allow-origins='*' "$@"
    '')
  ];

  # We manage Spotify's colors ourselves (Lain), not via Stylix's generated one.
  stylix.targets.spicetify.enable = false;

  programs.spicetify = {
    enable = true;
    colorScheme = "Hyprlain";
    theme = {
      name = "lain-color";
      src = lainColorTheme;
      # Recolor only: no CSS/JS injection, so Spotify's native layout is kept
      # intact and just repainted from color.ini via --spice-* variables.
      injectCss = false;
      replaceColors = true;
      injectThemeJs = false;
      homeConfig = false;
      overwriteAssets = false;
    };
  };
}
