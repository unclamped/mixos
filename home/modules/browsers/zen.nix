{ pkgs, inputs, ... }:

let
  exts = import ./extensions.nix { inherit pkgs; };

  # Hyprlain new-tab theming (Firefox-family userContent.css). The upstream file
  # references img/background.gif relatively; rewrite it to the store asset.
  hl = inputs.hyprlain-src;
  bgGif = "${hl}/src/dotfiles/src/chrome/img/background.gif";
  hyprlainUserContent = builtins.replaceStrings
    [ "url(img/background.gif)" ]
    [ ''url("${bgGif}")'' ]
    (builtins.readFile "${hl}/src/dotfiles/src/chrome/userContent.css");
in
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  stylix.targets.zen-browser.profileNames = [ "default" ];

  programs.zen-browser = {
    enable = true;
    policies.ExtensionSettings = exts.firefox;
    profiles.default.userContent = hyprlainUserContent;
  };
}
