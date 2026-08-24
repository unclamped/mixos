{ pkgs, lib, ... }:

let
  exts = import ./extensions.nix { inherit pkgs; };
in
{
  stylix.targets.librewolf.profileNames = [ "default" ];

  programs.librewolf = {
    enable = true;

    settings = {
      # Usability
      "webgl.disabled"                                         = false;
      "privacy.resistFingerprinting"                           = false;
      "security.OCSP.require"                                  = false;
      "browser.startup.page"                                   = 3;
      "privacy.sanitize.sanitizeOnShutdown"                    = false;
      "privacy.clearOnShutdown.cookies"                        = false;
      "privacy.clearOnShutdown.history"                        = false;
      "privacy.clearOnShutdown_v2.cookiesAndStorage"           = false;
      "privacy.clearOnShutdown_v2.historyFormDataAndDownloads" = false;
      "network.cookie.lifetimePolicy"                          = 0;

      # Hardware acceleration (VAAPI / WebRender)
      "gfx.webrender.all"                           = true;
      "gfx.canvas.accelerated"                      = true;
      "media.ffmpeg.vaapi.enabled"                  = true;
      "media.hardware-video-decoding.force-enabled"  = true;
      "media.av1.enabled"                           = true;
      "layers.acceleration.force-enabled"           = true;

      # Reduce I/O frequency
      "content.notify.interval"       = 100000;
      "browser.sessionstore.interval" = 60000;

      # Network throughput
      "network.http.max-connections"                       = 1800;
      "network.http.max-persistent-connections-per-server" = 10;

      # JIT
      "javascript.options.ion"           = true;
      "javascript.options.baselinejit"   = true;
      "javascript.options.native_regexp" = true;
    };

    policies.ExtensionSettings = exts.firefox;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html"                = [ "helium.desktop" ];
      "text/xml"                 = [ "helium.desktop" ];
      "x-scheme-handler/http"    = [ "helium.desktop" ];
      "x-scheme-handler/https"   = [ "helium.desktop" ];
      "x-scheme-handler/about"   = [ "helium.desktop" ];
      "x-scheme-handler/unknown" = [ "helium.desktop" ];
    };
  };
}
