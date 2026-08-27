{
  description = "Modular NixOS configuration with Hyprland";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Impermanence
    impermanence.url = "github:nix-community/impermanence";

    # Disko for declarative partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets with ragenix
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix for theming
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    # External kernel (nix-cachyos) for linux-cachyos-bore-lto
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel";
    };

    # nixcord (alternative Discord client)
    nixcord = {
      url = "github:FlameFlag/nixcord";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # spicetify-nix — themed Spotify
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # split-monitor-workspaces — Hyprland plugin giving each monitor its own
    # independent 1-N workspaces (so SUPER+number acts on the focused monitor).
    # follows our pinned Hyprland so the plugin ABI matches the compositor.
    # Vicinae - application launcher
    # Note: Do NOT add inputs.nixpkgs.follows to avoid cachix cache misses
    vicinae.url = "github:vicinaehq/vicinae";

    # Gaming: bleeding-edge proton-cachyos, mesa-git, etc.
    nix-gaming-edge = {
      url = "github:powerofthe69/nix-gaming-edge";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Enter the Wired (Accela / SLSteam launcher) — pins its own nixpkgs
    enter-the-wired.url = "github:ciscosweater/enter-the-wired";

    # SLSsteam — Steam library sharing via LD_AUDIT injection
    sls-steam = {
      url = "github:AceSLS/SLSsteam";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser (binary flake — no nixpkgs.follows to preserve cache hits)
    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    # Helium Browser (ungoogled-chromium fork — no nixpkgs.follows same reason)
    helium-browser.url = "github:schembriaiden/helium-browser-nix-flake";

    # Prism Launcher — no nixpkgs.follows to preserve cachix cache hits
    prismlauncher.url = "github:PrismLauncher/PrismLauncher";

    # IDA Pro local installation. Not distributable (proprietary, unfree), so
    # it's never committed — this must point at a pre-extracted IDA Pro
    # install that exists locally on whatever machine evaluates this flake.
    # Must be an ABSOLUTE path: a relative path: input is resolved through
    # this repo's git tree, which strips gitignored content (ida/ included),
    # so `path:./ida` fails even when the directory exists on disk.
    # Building pkgs.ida-pro or nixosConfigurations.turing on a machine other
    # than this one's requires:
    #   nix build .#nixosConfigurations.turing.config.system.build.toplevel \
    #     --override-input ida-src path:/absolute/path/to/your/ida
    ida-src = {
      url = "path:/home/maru/mixos/ida";
      flake = false;
    };

    # Hyprlain dotfiles — assets (wallpapers, icons, GIFs) for the Hyprlain
    # session. Public repo, so referenced directly instead of a local path.
    hyprlain-src = {
      url = "github:Ascaniolamp/Hyprlain";
      flake = false;
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, impermanence, disko, ragenix, stylix, hyprland, vicinae, rust-overlay, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

      username = "maru";

      # IDA Pro — adds pkgs.ida-pro from the local package. ida-src is a
      # path: flake input pointing at the gitignored ida/ directory; Nix
      # hashes it into flake.lock so pure eval mode is happy.
      #
      # This is shared by both hosts now. Note what that means for cerf: the
      # input is only FORCED when something actually references pkgs.ida-pro,
      # so a machine without /home/maru/mixos/ida can still evaluate the flake
      # right up until it tries to build a config that installs IDA. cerf does
      # install it, so cerf needs the directory copied over:
      #     rsync -a --delete ~/mixos/ida/ cerf:/home/maru/mixos/ida/
      #     rsync -a ~/.idapro/ cerf:/home/maru/.idapro/     # licence + config
      idaOverlay = { ... }: {
        nixpkgs.overlays = [
          (self: super: {
            ida-pro = super.callPackage ./packages/ida-pro.nix {
              idaSrc = inputs.ida-src;
            };
          })
        ];
      };

      # cisco-packet-tracer_9 in the pinned nixpkgs only knows about 9.0.0.
      # This overlay swaps in a patched copy (packages/cisco-packet-tracer-9.nix)
      # that adds 9.0.1 support and defaults to it. Drop this once the fix
      # lands upstream and the flake's nixpkgs input is bumped past it.
      ciscoPacketTracerOverlay = { ... }: {
        nixpkgs.overlays = [
          (self: super: {
            cisco-packet-tracer_9 = super.callPackage ./packages/cisco-packet-tracer-9.nix { };
          })
        ];
      };

      # Everything both hosts always want, in one list so a new host cannot
      # accidentally be assembled with half of it.
      commonModules = [
        disko.nixosModules.disko
        impermanence.nixosModules.impermanence
        ragenix.nixosModules.default
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        idaOverlay
        ciscoPacketTracerOverlay
      ];

      # Identical Home Manager wiring for every host; only the profile differs.
      hmFor = profile: {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          # Back up (instead of refusing to clobber) pre-existing on-disk
          # files that HM now wants to manage — e.g. Equibop writes
          # ~/.config/equibop/settings/quickCss.css at runtime before
          # nixcord's quickCss takes it over.
          backupFileExtension = "hm-bak";
          extraSpecialArgs = { inherit inputs username; };
          users.${username} = import profile;
        };
      };
    in
    {
      nixosConfigurations.turing = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username; };

        modules = commonModules ++ [
          # Add the cachyos kernel overlay so `pkgs.cachyosKernels` is available
          ({ pkgs, ... }:
            {
              nixpkgs.overlays = [ (inputs."nix-cachyos-kernel").overlays.pinned rust-overlay.overlays.default ];
              environment.systemPackages = [ pkgs.rust-bin.stable.latest.default ];
            }
          )

          ./hosts/turing
          (hmFor ./home/hosts/turing)
        ];
      };

      nixosConfigurations.cerf = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs username; };

        modules = commonModules ++ [
          ./hosts/cerf
          (hmFor ./home/hosts/cerf)
        ];
      };

      # Development shell for managing secrets
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          age
          ragenix.packages.${system}.default
          nixpkgs-fmt
        ];
      };
    };
}
