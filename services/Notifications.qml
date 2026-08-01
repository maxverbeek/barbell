pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications as Notif

// Notifications as they arrive, and nothing more — no history, no store. A
// notification lives as long as it's on screen and is gone once dismissed.
//
// Note this claims org.freedesktop.Notifications, so only one notification
// daemon can run at a time. While the ags bar is up it owns the name and
// nothing arrives here.
Singleton {
    id: root

    // Newest first, so the stack grows downward from the top of the screen in
    // the order things happened.
    property var active: []

    // How long each urgency stays up. Critical never expires on its own —
    // something that says it's critical has earned a deliberate dismissal.
    readonly property int lowTimeout: 4000
    readonly property int normalTimeout: 6000

    // More than this and they're a wall rather than information. Oldest go
    // first, since the newest is what just happened.
    readonly property int maxVisible: 5

    function timeoutFor(n) {
        if (n.urgency === Notif.NotificationUrgency.Critical) return 0;
        // The sender's own expireTimeout wins when it set one. -1 means "you
        // decide", 0 means "never".
        if (n.expireTimeout > 0) return n.expireTimeout;
        if (n.expireTimeout === 0) return 0;
        return n.urgency === Notif.NotificationUrgency.Low ? lowTimeout : normalTimeout;
    }

    // Two ways out, and senders can tell them apart: dismiss means a human
    // acted, expire means it timed out unread. Apps use that to decide
    // whether to clear a badge.
    function dismiss(n) { remove(n, true); }
    function expire(n) { remove(n, false); }

    function remove(n, byUser) {
        if (!n) return;
        const had = active.indexOf(n) !== -1;
        active = active.filter(x => x !== n);
        // A notification can go away underneath us — an action invoked it, the
        // sender closed it, the app quit — and calling dismiss/expire on the
        // destroyed object throws. Only tell the server about ones we were
        // still showing, and let the throw be non-fatal either way.
        if (!had) return;
        try {
            if (byUser) n.dismiss();
            else n.expire();
        } catch (e) {
            // Already closed on the server side; nothing left to tell it.
        }
    }

    function dismissAll() {
        for (const n of active.slice()) dismiss(n);
    }

    Notif.NotificationServer {
        id: server

        // Everything we can render. Claiming a capability we don't honour
        // makes senders send things that then don't show up.
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        inlineReplySupported: false
        persistenceSupported: false     // no history, and we say so

        // Survive a config reload without losing what's on screen.
        keepOnReload: true

        onNotification: n => {
            // Tracking is what keeps the object alive past this signal.
            n.tracked = true;

            // A repeat from the same app replacing its own notification
            // shouldn't stack up — drop the older one.
            const same = root.active.filter(x =>
                x.appName === n.appName && x.summary === n.summary);
            for (const old of same) root.dismiss(old);

            root.active = [n].concat(root.active);
            // Pushed off the bottom is closer to expiring than to being read.
            while (root.active.length > root.maxVisible)
                root.expire(root.active[root.active.length - 1]);
        }
    }

    // A notification that goes away on its own — closed by the sender, or the
    // app exiting — has to leave the list too.
    Connections {
        target: server
        function onTrackedNotificationsChanged() {
            const live = new Set(server.trackedNotifications?.values ?? []);
            const kept = root.active.filter(n => live.has(n));
            if (kept.length !== root.active.length) root.active = kept;
        }
    }
}
