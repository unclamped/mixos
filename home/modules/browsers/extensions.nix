# Pure helper — import as: import ./extensions.nix { inherit pkgs lib; }
# Returns { firefox = { "<id>" = policy_attrs; }; chromium = [ crx_attrs ]; }
{ pkgs, lib ? null }:

let
  mkFirefoxExt = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
    installation_mode = "force_installed";
  };

  mkChromiumExt = { id, version, hash }: {
    inherit id version;
    crxPath = pkgs.fetchurl {
      name = "${id}.crx";
      url = "https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3&prodversion=149&x=id%3D${id}%26installsource%3Dondemand%26uc";
      inherit hash;
    };
  };
in
{
  # ── Firefox-based browsers (LibreWolf, Floorp, Zen) ──────────────────────
  firefox = {
    "uBlock0@raymondhill.net"                = mkFirefoxExt "ublock-origin";
    "addon@darkreader.org"                   = mkFirefoxExt "darkreader";
    "foxyproxy@eric.h.jung"                  = mkFirefoxExt "foxyproxy-standard";
    "{4ee0a760-13e0-4ee5-af22-03099a45936d}" = mkFirefoxExt "steamcito-steam-impuestos-arg";
    "{1be309c5-3e4f-4b99-927d-bb500eb4fa88}" = mkFirefoxExt "augmented-steam";
    "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = mkFirefoxExt "violentmonkey";
    "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = mkFirefoxExt "return-youtube-dislikes";
    "sponsorBlocker@ajay.app"                = mkFirefoxExt "sponsorblock";
    "{446900e4-71c2-419f-a6a7-df9c091e268b}" = mkFirefoxExt "bitwarden-password-manager";
  };

  # ── Chromium-based browsers (Ungoogled Chromium) ─────────────────────────
  chromium = map mkChromiumExt [
    { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; version = "1.72.0";   hash = "sha256-b18FKOXz5mGKbIMd5TvmXz95KQ7fTT44Qzk46xGCQ/I="; } # uBlock Origin
    { id = "clngdbkpkpeebahjckkjfobafhncgmne"; version = "2.4.2";    hash = "sha256-3K3NCSJFyoY3Z5aEWNi2DWAucilJ3urHDuwSsev2Sv4="; } # Stylus
    { id = "nngceckbapebfimnlniiiahkandclblb"; version = "2026.6.0"; hash = "sha256-szBs8uPHBpgx4VAprSLOtD1XOAjUgecoAp6aJsvuT74="; } # Bitwarden
    { id = "aihndpeeoneojofmliffjknbegmipbim"; version = "1.1.0";    hash = "sha256-oR4q4U1R5GDjCkwwjZSMU0amR91+T1h76cpsjOxnGiM="; } # at://wormhole
    { id = "mnjggcdmjocbbbhaepdhchncahnbgone"; version = "6.1.6";    hash = "sha256-VYf+K2qZRhAcoN3nxu/nanVcXuW21uY9/EjH9zbNtP8="; } # SponsorBlock
    { id = "jghecgabfgfdldnmbfkhmffcabddioke"; version = "2.4.0";    hash = "sha256-dSLS7Km/5gbb07xEYACAOs9EBfvbJGlqx4qwFkKV95U="; } # Volume Master
    { id = "ndcooeababalnlpkfedmmbbbgkljhpjf"; version = "1.4.0";    hash = "sha256-8YLHEQogwSB+EDKIFqJycj5JcGHhRZxLwxYMS22ZRZ0="; } # ScriptCat
    { id = "ephjcajbkgplkjmelpglennepbpmdpjg"; version = "6.0.0";    hash = "sha256-4VEwf3rqtobbOElIsYi1mIcIvFS3KXlpHYfs3d+AzGg="; } # ff2mpv
    { id = "kpmjjdhbcfebfjgdnpjagcndoelnidfj"; version = "4.22.5";   hash = "sha256-CmJoZ+5vsk/T8cTP0LE+oGs8EM5nlzrLWn2MzoEMldM="; } # Control Panel for Twitter
    { id = "hlepfoohegkhhmjieoechaddaejaokhf"; version = "26.6.7";   hash = "sha256-Iht2QFqg3FixCfuX9fl4/SA9iXiK4x4t+vnlbS8Di1I="; } # Refined GitHub
  ];
}
