pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU and memory pressure, read straight from /proc on a timer. The numbers
// are only consumed past a threshold (see SysStatus), so nothing here needs to
// be fancier than "percent over the last poll interval".
Singleton {
    id: root

    // Busy % of all cores over the last interval, and used % of RAM
    // (1 - MemAvailable/MemTotal, the kernel's own idea of "actually free").
    property real cpu: 0
    property real mem: 0

    property double prevBusy: 0
    property double prevTotal: 0

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload(); }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            // cpu  user nice system idle iowait irq softirq steal ...
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.prevTotal > 0 && total > root.prevTotal)
                root.cpu = 100 * (total - idle - root.prevBusy) / (total - root.prevTotal);
            root.prevBusy = total - idle;
            root.prevTotal = total;
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const total = Number(text().match(/^MemTotal:\s+(\d+)/m)?.[1] ?? 0);
            const avail = Number(text().match(/^MemAvailable:\s+(\d+)/m)?.[1] ?? 0);
            if (total > 0) root.mem = 100 * (1 - avail / total);
        }
    }
}
