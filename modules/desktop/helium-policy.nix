{ ... }:

# Helium (ungoogled-chromium fork) ships its own managed policy
# (/etc/chromium/policies/managed/extra.json → BrowserThemeColor), which puts
# the browser in "managed" mode. Under management, Chromium blocks extensions
# loaded from the command line (--load-extension) unless they're explicitly
# allowed — hence "Lain Wired … is blocked by the administrator".
#
# Chromium merges every *.json in policies/managed/, so we drop a second file
# that allowlists our theme extension by its stable ID. The ID is deterministic
# because the theme manifest pins a `key` (see helium-lain-theme/manifest.json),
# so it no longer changes when the theme's store path changes.
let
  # ID derived from the manifest `key`: sha256(DER pubkey)[:16] hex, mapped a-p.
  lainThemeId = "ffpojnbapjjgfamccdbcnflmmcipeeph";
in
{
  environment.etc."chromium/policies/managed/helium-lain-ext.json".text = builtins.toJSON {
    ExtensionInstallAllowlist = [ lainThemeId ];
    ExtensionSettings = {
      "${lainThemeId}" = {
        installation_mode = "allowed";
      };
    };
  };
}
