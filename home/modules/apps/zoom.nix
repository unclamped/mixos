{ pkgs, ... }:

# ─── Zoom, without the Zoom client ──────────────────────────────────────────
#
# The official zoom-us package is a closed-source Electron blob with a
# genuinely bad privacy/security track record (the 2019 hidden local
# webserver that reinstalled itself and could be used for a webcam RCE, the
# now-removed attention-tracking feature, the 2020 LinkedIn "who is this
# person" data-mining panel, telemetry SDKs sharing data with Facebook). None
# of that runs if the app is never installed.
#
# Zoom's web client (no download required) covers joining and hosting
# ordinary meetings. What it can't do: some host-side controls on older
# accounts, and any meeting whose admin has disabled the "join from your
# browser" link outright — for those there is no way around the native app.
#
# The privacy trade rather than installing the client outright: run the web
# client in its own LibreWolf profile that is ALWAYS in private-browsing mode
# (nothing — cookies, cache, history, logins — ever touches disk, all of it
# is gone the moment the window closes) with fingerprint resistance on, fully
# separate from the daily-driver "default" profile's cookies/history/logins.
#
# `id = 1` keeps this out of the way of profileNames' "default" (id 0, and
# therefore the one and only isDefault — see
# home/modules/browsers/librewolf.nix and the assertion in home-manager's
# firefox module that exactly one profile may be default).
{
  programs.librewolf.profiles.zoom = {
    id = 1;

    settings = {
      # The core of the isolation: every window in this profile is a private
      # window, so nothing it touches is ever written to disk.
      "browser.privatebrowsing.autostart" = true;

      # librewolf.nix's global overrides.cfg loosens these for the default
      # profile's usability; user.js prefs set here are real user prefs, so
      # they win over that file's defaultPref values for THIS profile only.
      "privacy.resistFingerprinting"                = true;
      "privacy.trackingprotection.enabled"          = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
      "network.cookie.lifetimePolicy"               = 2; # session-only, moot under autostart-private but belt and suspenders

      "signon.rememberSignons"    = false;
      "identity.fxaccounts.enabled" = false;
      "geo.enabled"                = false;

      # Land straight on the "join without an account" screen.
      "browser.startup.homepage" = "https://zoom.us/wc";
      "browser.startup.page"     = 1;
    };
  };

  home.packages = [
    (pkgs.writeShellScriptBin "zoom" ''
      exec librewolf -P zoom --new-window "https://zoom.us/wc" "$@"
    '')
  ];

  xdg.desktopEntries.zoom-web = {
    name = "Zoom (isolated web client)";
    genericName = "Video Conferencing";
    comment = "Zoom's web client in a dedicated always-private-browsing LibreWolf profile — no Zoom desktop client installed";
    exec = "librewolf -P zoom --new-window https://zoom.us/wc";
    icon = "librewolf";
    terminal = false;
    categories = [ "Network" "AudioVideo" ];
  };
}
