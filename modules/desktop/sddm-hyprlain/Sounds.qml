// Isolated audio component for the Hyprlain SDDM theme.
//
// The upstream theme plays three sounds (bg music, welcome, deny) via Qt5
// `Audio` (QtMultimedia 5.5). That import previously took the WHOLE Main.qml
// down when it failed to resolve on the greeter's restricted QML path, dropping
// the theme to SDDM's blank fallback. So the risky `import QtMultimedia` now
// lives here, and Main.qml loads this file through a Loader: if the import (or
// audio backend) is missing, only the Loader fails — the theme still renders.
//
// Qt6 uses SoundEffect (lightweight, wav-oriented) instead of Qt5 Audio.
import QtQuick
import QtMultimedia

Item {
    function playWelcome() { welcome.play() }
    function playDenied()  { denied.play() }
    function playBg()      { bg.play() }

    SoundEffect { id: bg;      source: "assets/powerline.wav"; loops: SoundEffect.Infinite }
    SoundEffect { id: welcome; source: "assets/welcome.wav" }
    SoundEffect { id: denied;  source: "assets/denied.wav" }
}
