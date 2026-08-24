{
  pkgs,
  lib,
  idaSrc,
  extraFiles ? "",
  hexPatches ? [],
  # hexPatches: hex patterns to substitute in specified files immediately after
  # install. Can be used, for example, to replace the embedded SSL certificates
  # for compatibility with a self-hosted Lumina server.
  # Since IDA Pro is distributed as a binary, such patching is the only recourse
  # available to us for interoperability purposes.
  ...
}:
let
  pythonForIDA = pkgs.python313.withPackages (ps: with ps; [ rpyc ]);
  patchScript = lib.concatMapStringsSep "\n" (p:
    let
      forcecntDecl =
        lib.optionalString (p ? assertCount)
          "my $forcecnt = ${toString p.assertCount};";
          in ''
      perl -0777 -pi -e '${forcecntDecl} my $cnt = (s/\Q''${\pack("H*","${p.from}")}\E/''${\pack("H*","${p.to}")}/g) || 0; die "Expected $forcecnt substitutions, did $cnt\n" if defined $forcecnt && $cnt != $forcecnt' "$IDADIR/${p.filename}"
    ''
  ) hexPatches;
in
pkgs.stdenv.mkDerivation rec {
  pname = "ida-pro";
  version = "9.4";

  # Pre-extracted IDA installation kept locally at ida/ (gitignored).
  # Passed in from flake.nix as the ida-src path: input.
  src = idaSrc;

  desktopItem = pkgs.makeDesktopItem {
    name = "ida-pro";
    exec = "ida";
    icon = "${idaSrc}/appico.png";
    comment = meta.description;
    desktopName = "IDA Pro";
    genericName = "Interactive Disassembler";
    categories = [ "Development" ];
    startupWMClass = "IDA";
  };
  desktopItems = [ desktopItem ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
    qt6.wrapQtAppsHook
    perl
  ];

  # Add everything to the RPATH, in case IDA decides to dlopen things.
  runtimeDependencies = with pkgs; [
    cairo
    dbus
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libGL
    libkrb5
    libsecret
    qt6.qtbase
    qt6.qtwayland
    libunwind
    libxkbcommon
    libsecret
    openssl.out
    stdenv.cc.cc
    libice
    libsm
    libx11
    libxau
    libxcb
    libxext
    libxi
    libxrender
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
    zlib
    curl.out
    pythonForIDA
  ];
  buildInputs = runtimeDependencies;

  dontUnpack = true;
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/opt/.local/share/applications

    IDADIR="$out/opt"

    # Copy the pre-extracted installation and make files writable for patching.
    cp -r $src/. $IDADIR/
    chmod -R u+w $IDADIR

    ${patchScript}

    # Link the exported libraries to the output.
    for lib in $IDADIR/*.so $IDADIR/*.so.6; do
      ln -s $lib $out/lib/$(basename $lib)
    done

    # Manually patch libraries that dlopen stuff.
    patchelf --add-needed libpython3.13.so $out/lib/libida.so
    patchelf --add-needed libcrypto.so $out/lib/libida.so
    patchelf --add-needed libsecret-1.so.0 $out/lib/libida.so

    # Some libraries come with the installer.
    addAutoPatchelfSearchPath $IDADIR

    # Link the binaries to the output.
    # Also, hack the PATH so that pythonForIDA is used over the system python.
    for bb in ida; do
      wrapProgram $IDADIR/$bb \
        --prefix IDADIR : $IDADIR \
        --prefix QT_PLUGIN_PATH : $IDADIR/plugins/platforms \
        --prefix PYTHONPATH : $out/bin/idalib/python \
        --prefix PATH : ${pythonForIDA}/bin:$IDADIR \
        --prefix LD_LIBRARY_PATH : $out/lib
      ln -s $IDADIR/$bb $out/bin/$bb
    done

    if [ -n "${extraFiles}" ]
      then cp -r "${extraFiles}"/* $out/opt/
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "The world's smartest and most feature-full disassembler";
    homepage = "https://hex-rays.com/ida-pro/";
    license = licenses.unfree;
    mainProgram = "ida";
    maintainers = with maintainers; [ msanft ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
