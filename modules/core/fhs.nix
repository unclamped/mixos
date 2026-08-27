{ config, pkgs, lib, ... }:

# ─── Running ordinary (non-Nix) Linux binaries ──────────────────────────────
#
# NixOS has no /lib/ld-linux-x86-64.so.2, so a binary downloaded from anywhere
# else — a CTF challenge, a vendor SDK, a prebuilt toolchain, a pip wheel with
# bundled .so files — fails with "No such file or directory" even though the
# file is right there. Two mechanisms fix that, and this module enables both
# because they cover different cases.
#
# 1. nix-ld (below) installs a real interpreter at the standard path. Just run
#    the binary; if it only needs libraries listed here, it works with no
#    wrapper at all. This is the one you want 95% of the time.
#
# 2. `fhs` (below) drops you into a shell inside a full FHS sandbox, with
#    /usr/lib, /usr/bin and friends populated. Use it when a program does not
#    just need libraries but expects the LAYOUT — installers, .deb-extracted
#    trees, anything that shells out to /usr/bin/something.
#
# ── Cheat sheet for patching a binary properly instead ──────────────────────
#
#   # what does it actually want?
#   ldd ./thing                       # "not found" lines are the missing libs
#   nix-locate --top-level libfoo.so.1   # which package has it (nix-index)
#
#   # point it at the Nix loader and give it an RPATH — permanent, no wrapper
#   nix shell nixpkgs#patchelf nixpkgs#zlib nixpkgs#openssl
#   patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" ./thing
#   patchelf --set-rpath "$(nix eval --raw nixpkgs#zlib.outPath)/lib:..." ./thing
#
#   # or do all of that automatically (nix-alien is its own flake, not in
#   # nixpkgs, so it is run rather than installed)
#   nix run github:thiagokokada/nix-alien#nix-alien-ld -- ./thing
#
#   # one-off, no modification of the file
#   nix-shell -p zlib --run 'LD_LIBRARY_PATH=$LD_LIBRARY_PATH ./thing'

{
  programs.nix-ld = {
    enable = true;

    # The interpreter is useless without libraries to find. This is a
    # deliberately generous set: everything a typical prebuilt CLI tool, Qt/GTK
    # app, Electron blob or CUDA-free ML wheel reaches for.
    libraries = with pkgs; [
      # core
      stdenv.cc.cc.lib
      zlib
      zstd
      bzip2
      xz
      openssl
      curl
      libxml2
      libxslt
      icu
      glib
      glibc

      # crypto / auth
      libkrb5
      nss
      nspr
      p11-kit

      # graphics / GL
      libGL
      libglvnd
      mesa
      vulkan-loader
      libdrm
      libgbm

      # X11
      libx11
      libxcursor
      libxrandr
      libxi
      libxext
      libxrender
      libxfixes
      libxdamage
      libxcomposite
      libxtst
      libxcb
      libxscrnsaver
      libxkbfile
      libxkbcommon

      # wayland
      wayland

      # toolkits
      gtk3
      gdk-pixbuf
      cairo
      pango
      atk
      at-spi2-atk
      at-spi2-core
      freetype
      fontconfig
      harfbuzz
      expat
      dbus

      # media / audio
      alsa-lib
      pipewire
      libpulseaudio
      ffmpeg
      libva

      # misc things binaries commonly dlopen
      libusb1
      libudev-zero
      systemd
      util-linux
      cups
      nspr
      sqlite
      libsecret
    ];
  };

  environment.systemPackages = with pkgs; [
    # The FHS sandbox shell, for when nix-ld alone is not enough.
    (buildFHSEnv {
      name = "fhs";
      targetPkgs = p: (with p; [
        # a plausible "normal distro" userland
        coreutils util-linux findutils gnugrep gnused gawk which file
        bashInteractive gnutar gzip xz zstd unzip
        gcc gnumake binutils pkg-config
        python3 python3Packages.pip
        curl wget git openssh
        zlib openssl ncurses readline
        libxml2 libxslt sqlite
        glib gtk3 cairo pango gdk-pixbuf atk
        libGL libglvnd mesa vulkan-loader libdrm
        libx11 libxcursor libxrandr libxi libxext
        libxrender libxfixes libxdamage libxcomposite
        libxtst libxcb libxkbcommon
        alsa-lib libpulseaudio
        nss nspr expat dbus fontconfig freetype
        stdenv.cc.cc.lib
      ]);
      runScript = "bash";
      profile = ''
        export FHS=1
        export PS1='(fhs) \u@\h:\w\$ '
      '';
    })

    # Tooling for the "patch it properly" path documented above.
    patchelf
    file
    binutils        # readelf, objdump, strings
  ];

  # nix-locate ("which package has libfoo.so.1?"), which the cheat sheet above
  # depends on. Populate/refresh the index with `nix-index`; it is a download,
  # not a build.
  programs.nix-index.enable = true;
  # nix-index and command-not-found both want to own the shell's
  # "command not found" hook, and NixOS refuses to enable both.
  programs.command-not-found.enable = false;
}
