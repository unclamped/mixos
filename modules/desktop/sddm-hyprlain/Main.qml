// Qt6 port of the upstream Hyprlain SDDM theme Main.qml.
// Upstream targets Qt5 (QtQuick.Controls 1.4 + Styles 1.4, QtMultimedia 5.5
// Audio), which crashes the Qt6 sddm-greeter. Changes vs upstream:
//   - versionless Qt6 imports; dropped QtQuick.Controls.Styles (removed in Qt6)
//   - TextField styled inline (color + background Rectangle) instead of TextFieldStyle
//   - Audio restored, but ISOLATED in Sounds.qml (loaded via a Loader). A bad
//     `import QtMultimedia` used to take the WHOLE Main.qml down to SDDM's blank
//     fallback; keeping the import in a Loader-loaded file means a failure loses
//     only the sound, not the theme. qtmultimedia is in the SDDM extraPackages.
//   - Connections/Keys handlers use the Qt6 function(...) form
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Qqc
import QtQuick.Window
import SddmComponents 2.0

Rectangle {
	color: "black"
	width: Screen.width
	height: Screen.height

	// Login sounds live in a separate file loaded here, so that if the
	// QtMultimedia import or audio backend is unavailable the theme still
	// renders (the Loader fails in isolation instead of taking Main.qml down).
	Loader {
		id: sounds
		source: "Sounds.qml"
		asynchronous: true
	}

	Connections {
		target: sddm
		function onLoginSucceeded() {}
		function onLoginFailed() { if (sounds.item) sounds.item.playDenied() }
	}

	AnimatedImage {
		width: parent.width
		height: parent.height
		fillMode: Image.Tile
		source: "assets/bg_darker.gif"
	}

	AnimatedImage {
		width: parent.width
		height: parent.height
		fillMode: Image.Tile
		source: "assets/bg_dark_anim_0_08.gif"
	}

	ColumnLayout {
		width: parent.width
		height: parent.height
		AnimatedImage{
			Layout.alignment: Qt.AlignCenter
			Layout.topMargin: 2
			width: 192
			height: 192
			source: "assets/wiredLogInNew_512px_06.gif"
		}
		Qqc.Label {
			Layout.alignment: Qt.AlignCenter
			text: "U s e r  I D:"
			color: "#c1b492"
		}
		Qqc.TextField {
			id: username
			Layout.alignment: Qt.AlignCenter
			text: userModel.lastUser
			color: "#c1b492"
			implicitWidth: 200
			background: Rectangle {
				color: "#000"
				implicitWidth: 200
				border.color: "#d2738a"
			}
			KeyNavigation.backtab: shutdownBtn; KeyNavigation.tab: password
			Keys.onPressed: function(event) {
				if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
					sddm.login(username.text, password.text, session.index)
					event.accepted = true
				}
			}
		}
		Qqc.Label {
			Layout.alignment: Qt.AlignCenter
			text: "P a s s w o r d:"
			color: "#c1b492"
		}
		Qqc.TextField {
			id: password
			echoMode: TextInput.Password
			Layout.alignment: Qt.AlignCenter
			color: "#c1b492"
			implicitWidth: 200
			background: Rectangle {
				color: "#000"
				implicitWidth: 200
				border.color: "#d2738a"
			}
			KeyNavigation.backtab: username; KeyNavigation.tab: session
			Keys.onPressed: function(event) {
				if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
					sddm.login(username.text, password.text, session.index)
					event.accepted = true
				}
			}
		}
		ColumnLayout {
			Layout.alignment: Qt.AlignCenter
			Layout.topMargin: 4
			Layout.bottomMargin: 50
			width: 200
			Rectangle {
				anchors.fill: parent
				color: "#d2738a"
			}
			Qqc.Label {
				Layout.alignment: Qt.AlignCenter
				text: "L o g i n"
				color: "#c1b492"
			}
			MouseArea {
				anchors.fill: parent
				onClicked: sddm.login(username.text, password.text, session.index)
			}
		}
	}
	AnimatedImage {
		id: shutdownBtn
		height: 80
		width: 80
		y: 10
		x: Screen.width - width - 10
		source: "assets/VisLain.gif"
		fillMode: Image.PreserveAspectFit
		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
			onClicked: sddm.powerOff()
			onEntered: {
				var component = Qt.createComponent("ShutdownToolTip.qml");
				if (component.status == Component.Ready) {
					var tooltip = component.createObject(shutdownBtn);
					tooltip.x = -45
					tooltip.y = 60
				tooltip.destroy(500);
				}
			}
		}
	}
	AnimatedImage {
		id: rebootBtn
		anchors.right: shutdownBtn.left
		anchors.rightMargin: 5
		y: shutdownBtn.y + 10
		height: 70
		width: 60
		source: "assets/lain_myese.gif"
		fillMode: Image.PreserveAspectFit
		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
			onClicked: sddm.reboot()
			onEntered: {
				var component = Qt.createComponent("RebootToolTip.qml");
				if (component.status == Component.Ready) {
					var tooltip = component.createObject(rebootBtn);
					tooltip.x = -45
					tooltip.y = 50
				tooltip.destroy(500);
				}
			}
		}
	}
	ComboBox {
		id: session
		height: 30
		width: 200
		x: 15
		y: 20
		model: sessionModel
		index: sessionModel.lastIndex
		color: "#000"
		borderColor: "#d2738a"
		focusColor: "#d2738a"
		hoverColor: "#d2738a"
		textColor: "#c1b492"
		arrowIcon: "assets/angle-down.png"
		KeyNavigation.backtab: password; KeyNavigation.tab: rebootBtn;
	}
	Component.onCompleted: {
		if (sounds.item) {
			sounds.item.playBg()
			sounds.item.playWelcome()
		}
		if (username.text == "") {
			username.focus = true
		} else {
			password.focus = true
		}
	}
}
