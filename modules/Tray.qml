import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

// StatusNotifier tray, for the apps that only talk through it — Slack's
// unread badge, and whatever else insists on living there.
//
// The bar already has first-class widgets for network, bluetooth and audio,
// so their applets' tray icons would say the same thing twice; anything on
// the blocklist is dropped rather than drawn.
RowLayout {
    id: root
    spacing: 8

    // Matched as a substring of the item's StatusNotifier id, lowercased.
    readonly property var hidden: ["nm-applet", "blueman"]

    Repeater {
        model: SystemTray.items.values.filter(i =>
            !root.hidden.some(h => (i.id ?? "").toLowerCase().includes(h)))

        Item {
            id: item
            required property var modelData

            implicitWidth: 16
            implicitHeight: 16
            Layout.alignment: Qt.AlignVCenter

            // Some apps register a tray item under an icon name the theme
            // doesn't have (wayscriber, at time of writing). The icon image
            // provider serves its magenta missing-texture checker for those —
            // a successful load, so Image.status never says Error and the
            // name has to be checked against the theme ourselves.
            readonly property bool broken: {
                const src = modelData.icon ?? "";
                if (src === "") return true;
                const m = /^image:\/\/icon\/([^?]+)$/.exec(src);
                return m !== null && !Quickshell.hasThemeIcon(m[1]);
            }

            IconImage {
                anchors.fill: parent
                visible: !item.broken
                source: item.broken ? "" : item.modelData.icon
            }

            // A generic glyph at least looks meant.
            Text {
                anchors.centerIn: parent
                visible: item.broken
                text: "󰀻"
                font { family: Theme.iconFont; pixelSize: 14 }
                color: Theme.fgDim
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    // Left activates the app; some items are menu-only and
                    // have nothing to activate, so they get the menu too.
                    if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) {
                        modelData.activate();
                        return;
                    }
                    // display() shows the item's own dbusmenu — native, so
                    // there's no menu UI to maintain here. Anchored under the
                    // icon in window coordinates.
                    const pos = mapToItem(null, 0, height);
                    modelData.display(QsWindow.window, pos.x, pos.y);
                }
            }
        }
    }
}
