import QtQuick
import Quickshell
import "services" as Svc

ShellRoot {
    Timer {
        running: true; interval: 2500
        onTriggered: {
            console.log("players:", Svc.Media.players.length);
            for (const p of Svc.Media.players)
                console.log("  ", JSON.stringify(p.identity), "| dbus:", p.dbusName,
                            "| canControl:", p.canControl, "| playing:", p.isPlaying,
                            "| title:", JSON.stringify(p.trackTitle));
            console.log("chosen:", Svc.Media.player ? Svc.Media.app : "none",
                        "| active:", Svc.Media.active);
            Qt.exit(0);
        }
    }
}
