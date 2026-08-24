{ pkgs, ... }:

let
  exts = import ./extensions.nix { inherit pkgs; };
in
{
  stylix.targets.floorp.profileNames = [ "default" ];

  programs.floorp = {
    enable = true;
    policies.ExtensionSettings = exts.firefox;
  };
}
