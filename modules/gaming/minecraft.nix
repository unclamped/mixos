{ config, pkgs, inputs, ... }:

{
  assertions = [
    {
      assertion = config.programs.gamemode.enable;
      message = "modules/gaming/minecraft: requires programs.gamemode.enable = true (already set in steam.nix)";
    }
  ];

  # Prism Launcher binary cache
  nix.settings = {
    trusted-substituters = [ "https://prismlauncher.cachix.org" ];
    trusted-public-keys = [
      "prismlauncher.cachix.org-1:9/n/FGyABA2jLUVfY+DEp4hKds/rwO+SCOtbOkDzd+c="
    ];
  };

  # Zulu as the system-wide default JDK; GraalVM available as a secondary option.
  # Prism Launcher auto-detects both from PATH for per-instance selection.
  programs.java = {
    enable = true;
    package = pkgs.zulu25;
  };

  environment.systemPackages = [
    inputs.prismlauncher.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
    (pkgs.lib.lowPrio pkgs.graalvmPackages.graalvm-ce)
  ];
}
