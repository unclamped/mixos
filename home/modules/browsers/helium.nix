{ pkgs, inputs, ... }:

let
  heliumPkg = inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Lain Chromium UI theme (frame/toolbar/tabs/omnibox), packaged as an unpacked
  # theme extension. Loaded via --load-extension so it recolors Helium's own
  # chrome (not just page content).
  lainTheme = ./helium-lain-theme;

  # Debug launcher for the chrome-devtools MCP: an ISOLATED profile with the CDP
  # remote-debugging port open and the Lain theme loaded, so the MCP can attach
  # and we can iterate on the theme from screenshots — without exposing the
  # user's real browsing profile or opening a debug port on their daily browser.
  #   Connect the MCP with: --browserUrl http://127.0.0.1:9222
  heliumDebug = pkgs.writeShellScriptBin "helium-debug" ''
    exec ${heliumPkg}/bin/helium \
      --user-data-dir="$HOME/.local/share/helium-debug" \
      --remote-debugging-port=9222 \
      --remote-allow-origins='*' \
      --load-extension=${lainTheme} \
      --no-first-run \
      "$@"
  '';

  # Main Helium, wrapped to auto-load the Lain UI theme on every launch (no debug
  # port — safe for daily use).
  heliumThemed = pkgs.symlinkJoin {
    name = "helium-lain";
    paths = [ heliumPkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/helium \
        --add-flags "--load-extension=${lainTheme}"
    '';
  };
in
{
  home.packages = [
    heliumThemed
    heliumDebug
  ];
}
