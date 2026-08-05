import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import ".."

// StatusNotifier tray, for the apps that only talk through it — Slack's
// unread badge, and whatever else insists on living there.
//
// Every item shows, unfiltered: the applets that would duplicate the bar's
// own widgets (nm-applet, blueman) aren't autostarted anymore, and if one is
// running anyway it's because it was started on purpose.
RowLayout {
    id: root
    spacing: 8

    // A nested layout defaults to fillWidth: true, which makes an empty tray
    // stretch like a spacer and shove everything after it off-centre.
    Layout.fillWidth: false

    // A zero-width tray still earns the bar's spacing on both sides — a
    // double gap between kube and the island — unless it's hidden outright.
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

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

            // Spotify's tray icon decodes to a 0×0 nothing — a successful load
            // of a blank image, indistinguishable via any IconImage property
            // from an icon that renders fine. So it's a named exception: draw
            // its own glyph instead of the (missing) icon.
            readonly property bool spotify: modelData.id === "spotify-client"

            IconImage {
                anchors.fill: parent
                visible: !item.broken && !item.spotify
                source: item.broken ? "" : item.modelData.icon
            }

            // A generic glyph for a theme-name miss; Spotify's own logo for the
            // one app that hands us a blank icon.
            Text {
                anchors.centerIn: parent
                visible: item.broken || item.spotify
                text: item.spotify ? "󰓇" : "󰀻"
                font { family: Theme.iconFont; pixelSize: item.spotify ? 15 : 14 }
                color: item.spotify ? Theme.good : Theme.fgDim
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
