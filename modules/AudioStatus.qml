import QtQuick
import ".."
import "../services"

// Speaker and mic, following the interest rules:
//   speaker — always drawn, it's the button into the audio menu. One shape
//             throughout; colour says where the sound is going.
//   mic     — drawn only when something is listening or it's muted. Muted
//             *while* something wants it is the loud case: you're talking and
//             nobody can hear you.
Row {
    spacing: 12

    signal openMenu()

    Text {
        visible: Audio.micInUse || Audio.micMuted
        text: Audio.micMuted ? "󰍭" : "󰍬"
        font { family: Theme.iconFont; pixelSize: 15 }
        color: Audio.micMuted
            ? (Audio.micInUse ? Theme.bad : Theme.warn)  // in-use+muted is the mistake
            : Theme.good
        anchors.verticalCenter: parent.verticalCenter

        // Muted while something is capturing is worth a second glance, so it
        // breathes. Nothing else on the bar animates at rest.
        SequentialAnimation on opacity {
            running: Audio.micMuted && Audio.micInUse
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
        }
        onVisibleChanged: if (!visible) opacity = 1
    }

    Text {
        text: Audio.sinkMuted ? "󰝟" : "󰕾"
        font { family: Theme.iconFont; pixelSize: 15 }
        color: Audio.sinkMuted ? Theme.bad
            : Audio.sinkIsBluetooth ? Theme.accent
            : Theme.fg
        anchors.verticalCenter: parent.verticalCenter

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4          // a 15px glyph is a small target
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) Audio.toggleSinkMute();
                else parent.parent.openMenu();
            }
            onWheel: wheel => Audio.setSinkVolume(
                Audio.sinkVolume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }
}
