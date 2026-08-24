{ pkgs, inputs, ... }:

let
  accela-raw = inputs.enter-the-wired.packages.x86_64-linux.default;

  sls-steam-so = inputs.sls-steam.packages.x86_64-linux.default;

  # LD_AUDIT must be set inside the FHS container (where the 32-bit steamclient
  # actually lives), not on the outer 64-bit bubblewrap wrapper. Using
  # programs.steam.package with extraEnv is the correct injection point.
  steam-with-sls = pkgs.steam.override {
    extraEnv = {
      LD_AUDIT = "${sls-steam-so}/library-inject.so:${sls-steam-so}/SLSsteam.so";
      # Inherited by every game process Steam spawns; auto-registers each with the gamemode daemon
      LD_PRELOAD = "${pkgs.gamemode}/lib/libgamemodeauto.so";
      # Let sandboxed (bwrap) Steam games reach the WiVRn OpenXR IPC socket for VR.
      PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
    };
  };

  # Convenience alias so `SLSsteam` works as DeveloperMikey's README describes.
  sls-steam = pkgs.writeShellScriptBin "SLSsteam" ''
    exec steam "$@"
  '';

  # The bundled libxdg-shell.so crashes in requestActivate under Hyprland when
  # launched via a Wayland-native launcher. Forcing XCB bypasses that path.
  accela = pkgs.symlinkJoin {
    name = "accela";
    paths = [ accela-raw ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/accela \
        --set QT_QPA_PLATFORM xcb
    '';
  };

  # protontricks runs outside Steam's bwrap, so STEAM_EXTRA_COMPAT_TOOLS_PATHS
  # (set in the FHS profile) is invisible to it. Inject it here so it can
  # locate proton-cachyos and proton-ge-bin the same way Steam does.
  protontricks-wrapped = pkgs.symlinkJoin {
    name = "protontricks";
    paths = [ pkgs.protontricks ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/protontricks \
        --set STEAM_EXTRA_COMPAT_TOOLS_PATHS "${pkgs.proton-cachyos.steamcompattool}:${pkgs.proton-ge-bin.steamcompattool}"
    '';
  };
in
{
  nixpkgs.overlays = [
    inputs.nix-gaming-edge.overlays.default
  ];

  # Binary cache for proton-cachyos and other nix-gaming-edge pre-built packages
  nix.settings = {
    substituters = [ "https://nix-cache.tokidoki.dev/tokidoki" ];
    trusted-public-keys = [
      "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk="
    ];
  };

  hardware.steam-hardware.enable = true;

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        inhibit_screensaver = 1;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
      };
      cpu = {
        park_cores = "no";
        pin_cores = "yes";
      };
    };
  };

  programs.steam = {
    enable = true;
    package = steam-with-sls;
    extraCompatPackages = with pkgs; [
      proton-cachyos
      proton-ge-bin
    ];
    extraPackages = with pkgs; [ libnotify ];
  };

  environment.systemPackages = with pkgs; [
    steam-tui
    accela
    sls-steam
    libnotify
    protontricks-wrapped
  ];
}
